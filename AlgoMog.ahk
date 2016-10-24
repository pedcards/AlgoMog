/*	ALGAE transmogrifier, (C) TC 2013-2014
	Tool for converting XML files into $elem() array blocks for use in ALGAE scripts.
	ALGAE = Algorithm Logic Graphical Application Encoder
	
    Ver 1.1 (1/11/14) - Draw.io now exports mxGraph XML files, which have more metadata than before. Need to use real XML parsing. Using the xml.ahk script discussed here: http://www.autohotkey.com/board/topic/89197-xml-build-parse-xml/
	Ver 1.2 (1/19/14) - Reads Draw.io XML file and parses properly. Compresses nodes sequentially. 
	Ver 1.3 (1/23/14) - Added autodetection of mxGraph XML vs Visio VDX files. Special thanks to maestrith from AHK forums for the help parsing the broken VDX format. Apparently, the xml.ahk script does not handle broken XML very well. Needed to comment out line 138 to make it recognize the M$ XML file. Also, did not work on Win7 machine unless I commented out the (A_OSVersion ... ) in line 129. 
	Ver 1.4 - Convert to $elem() block for faster PHP parsing. Or parse XML in PHP? Option to save both! Still need to improve behavior for terminators. May possibly require 
*/

#Include xml.ahk
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%

FileSelectFile, filename,,, Select XML file:, XML files (*.xml;*.vdx)
FileRead, xfile, %filename%

x := new XML(xfile)				; XML file in
y := new XML("<root/>")			; XML file for output

If (x.selectNodes("/mxGraphModel").length) {			; Identified as a mxGraphModel from Draw.io
	Loop, % (mxC:=x.selectNodes("//mxCell")).length {	; Number of shape types
		k := mxC.item((i:=A_Index)-1)					; Get next type
		mxID := k.getAttribute("id")
		mxParent := k.getAttribute("parent")
		mxValue := k.getAttribute("value")
		mxValue := RegExReplace(mxValue, "<[^>]+>" , "")	; Strip out HTML tags http://www.autohotkey.com/board/topic/10707-fastest-way-to-remove-html-tags/?p=89378
		mxStyle := k.getAttribute("style")
		mxSource := k.getAttribute("source")
		mxTarget := k.getAttribute("target")

		IfInString, mxStyle, shape		; Any non-connector shape will do
		{
			y.addElement("elem", "root", {id: mxID})		; Create new node in Y
			y.addElement("display", "//elem[@id='" mxID "']", mxValue)		; Create element <display> with text field
		}
	  
		IfInString, mxStyle, endArrow		; denotes a connector
		{
			if ((mxSource = "") or (mxTarget = "")) {		; If connector has either no valid source or target 
				linerr := mxSource . mxTarget				; Concat string of source and target (one or both will be "")
				boxerr := y.SelectSingleNode("//elem[@id='" mxSource "']").text		; Get the elem text for the Source and Target
				MsgBox , , Diagram ERROR, % "Broken link at`nNode: " mxSource . mxTarget "`n`n" boxerr
			} else {
				y.addElement("option", "//elem[@id='" mxSource "']", {target: mxTarget}, mxValue)
			}
		}
	}
	y.viewXML()
} 

If (x.selectNodes("/VisioDocument").length) {		; For VDX "VisioDocument" files. Had to comment out line 138 in xml.ahk
	mxClass := []
	Loop, % (mxC:=x.selectNodes("//Master")).length {		; Scan through form elements
		k := mxC.item((i:=A_Index)-1)						; Get next node from X
		mxID := k.getAttribute("ID")
		mxNameU := k.getAttribute("NameU")
			IfInString, mxNameU, connector					; Any of the connector types are equal
			{
				mxNameU := "Connector"
			}
		mxClass[mxID] := mxNameU 
	}
	Loop, % (mxC:=x.selectNodes("//Page/Shapes/Shape")).length {		; Scan through cells
		k := mxC.item((i:=A_Index)-1)
		mxID := k.getAttribute("ID")						; Cell number
		mxType := k.getAttribute("Master")					; Master form index
		mxValue := k.selectSingleNode("Text").text			; Label for the cell
		
		If (mxClass[mxType] == "Connector") {				; For connector types
			mxSource := x.selectSingleNode("//Connect[@FromSheet='" mxID "'][@FromCell='BeginX']").getAttribute("ToSheet")
			mxTarget := x.selectSingleNode("//Connect[@FromSheet='" mxID "'][@FromCell='EndX']").getAttribute("ToSheet")
			y.addElement("option", "//elem[@id='" mxSource "']", {target: mxTarget}, mxValue)
		} else {											; Anything else is a non-connector
			y.addElement("elem", "root", {id: mxID})		; Create new node in Y
			y.addElement("display", "//elem[@id='" mxID "']", mxValue)		; Create element <display> with text
		}
	}
	y.viewXML()
}

/*
	Collapse the nodes numbering.
	Traverse each node. For each Elem, reindex sequentially.
	Traverse all //elem/option elements (links). Replace references to the oldID with the newID. 
*/
elemblock := ""
Loop, % (elemnode:=y.selectNodes("//elem")).length {
	k := elemnode.item((i:=A_Index)-1)
	k1 := k.getAttribute("id")
	k.setAttribute("id", i)
	k2 := k.selectSingleNode("display").text
	Loop, % (elemelems:=y.selectNodes("//elem/option")).length {
		kk := elemelems.item((j:=A_Index)-1)
		If (kk.getAttribute("target") = k1) {
			kk.setAttribute("target", i)
		}
	}
}

y.viewXML()

/*	Convert to $elem() block or keep as XML?
	The latter would be more futureproof.
*/
MsgBox, 36, Choose format to save, Save as $elem( ) block? `n(No = XML)
IfMsgBox, Yes 
{
	elemblock := ""
	Loop, % (elemnode:=y.selectNodes("//elem")).length {
		k := elemnode.item((i:=A_Index)-1)
		k1 := k.getAttribute("id")
		k2 := k.selectSingleNode("display").Text
		elemblock .= "$elem[1][" . i . "] = array(1, ""title"" , """ . k2 . """,`n"
		Loop, % (elemelems:=k.selectNodes("option")).length {
			kk := elemelems.item((j:=A_Index)-1)
			kk1 := kk.getAttribute("target")
			elemblock .= "    """ . kk.text . """, " . kk1 . ",`n"
		}
		StringTrimRight, elemblock, elemblock, 2
		elemblock .= ");`n"
	}
	MsgBox, % elemblock
	FileDelete, elem.txt
	FileAppend, % elemblock , elem.txt
} else {
	y.save("test.xml")
	MsgBox, XML done!
}

ExitApp
