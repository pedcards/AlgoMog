/*	ALGAE transmogrifier, (C) TC 2013-2014
	Tool for converting XML files into $elem() array blocks for use in ALGAE scripts.
	ALGAE = Algorithm Logic Graphical Application Encoder
	
    Ver 1.1 (1/11/14) - Draw.io now exports mxGraph XML files, which have more metadata than before. Need to use real XML parsing. Using the xml.ahk script discussed here: http://www.autohotkey.com/board/topic/89197-xml-build-parse-xml/
	
	Ver 1.2 (1/19/14) - Reads Draw.io XML file and parses properly. Compresses nodes sequentially. 
	
	Ver 1.3 (1/23/14) - Added autodetection of mxGraph XML vs Visio VDX files. Special thanks to maestrith from AHK forums for the help parsing the broken VDX format. Apparently, the xml.ahk script does not handle broken XML very well. Needed to comment out line 138 to make it recognize the M$ XML file. Also, did not work on Win7 machine unless I commented out the (A_OSVersion ... ) in line 129. 
	
	Ver 1.4 (1/29/14) - Convert to $elem() block for faster PHP parsing. Consider parse XML in PHP for greater flexibility. Option to save both! 
	
	Ver 1.5 - ALGAE script modified to load XML, with error checking if $XML object already loaded. Bad connectors added to errorlog, displayed at end and file not saved. Annotation boxes don't have configurable connectors. Title text bracketed by "::". 
	
	Ver 1.6 - <nl> converted to <br> and trimmed from edges.
	
	Ver 1.7 - Changed logic of Annotations to create <note> element. Allows creation of large notes and avoids collisions with "target" attribute. Correctly saves output to same dir as input file.
*/
/*	TODO (AlgoMog):
	- Account for pages. 
		- Get pages: <Pages/Page ID="0" NameU="Page-1"/PageSheet UniqueID='{xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx}>
		- Index pages sequentially, PgID
		- When scanning cells, add the PgID as 100's place for each MxID. Page-1 cell-16 would become 116, Page-2 cell-9 would be 209. Works for <100 elements per page.
		- MxID node numbers will be collapsed in the last step.
	- Off-page links. 
		- Don't count the outgoing and incoming link in rendering jump links.
		- Target page is in: <Shape/User NameU='OPCDPageID'/Value> matches the PageSheet UniqueID.
		- Target node is in: <Shape/User NameU='OPCDShapeID'/Value> matches the Shape UniqueID.
	- On-page links.
	- Generate app dir and Algo.php for app.
	- Add GUI for title info.
	- Image elements? Image files in ./Images or such.
	- Handling of text formatting.
	- Deflate XML for insertion into text.
	
	TODO (Algo.php):
	- Keep title persistent until change?
	
*/

#Include xml.ahk
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%

FileSelectFile, filename,,, Select XML file:, XML files (*.xml;*.vdx;*.vsdx)
splitpath, filename, outfilename, outdir, outext, outname
SetWorkingDir, %outdir%
if instr(filename,".vsdx") {
	xfile := readV2016(filename)
} else {
	FileRead, xfile, %filename%
}
outname := outname . "-elem.xml"


x := new XML(xfile)				; XML file in
y := new XML("<root/>")			; XML file for output
errtext := ""

y.addelement("settings", "root")
y.addelement("theme", "//settings", "A")				; A=light, B=dark
y.addelement("title", "//settings", "Main Title")		; Main title for the Algo
y.addelement("ver", "//settings", "0.1")				; Version number

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
}	; End MxGRAPHMODEL scan

If (x.selectNodes("/VisioDocument").length) {		; For VDX "VisioDocument" files. Had to comment out line 138 in xml.ahk
	mxClass := []
	Loop, % (mxC:=x.selectNodes("//Master")).length {		; Scan through master form elements
		k := mxC.item((i:=A_Index)-1)						; Get next node from X
		mxID := k.getAttribute("ID")
		mxNameU := k.getAttribute("NameU")
			IfInString, mxNameU, connector					; Any of the connector types are equal
			{
				mxNameU := "Connector"
			}
			IfInstring, mxNameU, annotation					; Any annotation
			{
				mxNameU := "Annotation"
			}
		mxClass[mxID] := mxNameU
	}
	Loop, % (mxP:=x.selectNodes("//Pages/Page")).length {	; Scan through each page
		p := mxP.item((j:=A_Index)-1)
		jIdx := j*1000
		Loop, % (mxC:=p.selectNodes("Shapes/Shape")).length {		; Scan through cells
			k := mxC.item((i:=A_Index)-1)
			mxID := k.getAttribute("ID")						; Cell number
			mxType := k.getAttribute("Master")					; Master form index
			mxValue := k.selectSingleNode("Text").text			; Label for the cell
			StringReplace, mxValue, mxValue, `n, <br>, ALL
	 
			If (mxClass[mxType] == "Annotation") {				; Note box
				mxSource := p.selectSingleNode("Connects/Connect[@FromSheet='" mxID "']").getAttribute("ToSheet")
				mxValue := k.selectSingleNode("Shapes/Shape/Text").text				; New cell defined in "//Page/Shapes/Shape/Shapes/Shape/"
				TrimBr(mxValue)
				y.addElement("note", "//elem[@id='" (mxSource+jIDX) "']", mxValue)	; Add Note element.
				continue
			}
			If (mxClass[mxType] == "Connector") {				; For connector types
				mxSource := p.selectSingleNode("Connects/Connect[@FromSheet='" mxID "'][@FromCell='BeginX']").getAttribute("ToSheet")
				mxTarget := p.selectSingleNode("Connects/Connect[@FromSheet='" mxID "'][@FromCell='EndX']").getAttribute("ToSheet")

				If ((mxSource == "") or (mxTarget == "")) {		; Error checking for connectors
					errtext .= y.selectSingleNode("//elem[@id='" mxSource . mxTarget "']/display").text . mxSource . mxTarget . "`n"
				}
				trimBR(mxValue)
				y.addElement("option", "//elem[@id='" (mxSource+jIDX) "']", {target: (mxTarget+jIDX)}, mxValue)
				continue
			}
			If (mxClass[mxType] == "Off-page reference") {		; Section for Off-page connections
				mxSource := k.selectSingleNode("User[@NameU='OPCShapeID']/Value").Text		; this node's UID
				mxTarget := k.selectSingleNode("User[@NameU='OPCDShapeID']/Value").text		; get the target UID
				y.addElement("elem", "root", {id: (mxID+jIDX)}, {UID: mxSource}, {link: mxTarget})		; Create a new node
				continue
			} else {											; Anything else is a NODE
				y.addElement("elem", "root", {id: (mxID+jIDX)})		; Create new node in Y
				IfInString, mxValue, :: 
				{
					StringSplit, title, mxValue, :,%A_Space%	; Split titles.
					mxTitle := title3
					mxValue := title5
					TrimBR(mxTitle)
					y.addElement("title", "//elem[@id='" (mxID+jIDX) "']", mxTitle)		; If exists, add <title> element
				}	
				TrimBR(mxValue)
				y.addElement("display", "//elem[@id='" (mxID+jIDX) "']", mxValue)		; Create element <display> with text
			}
		}	; End NODES loop
	}	; End PAGES loop
}	; End VISIO document scan

y.viewXML()

/*
	Collapse the nodes numbering.
	Traverse each node. For each Elem, reindex sequentially.
	Traverse all //elem/option elements (links). Replace references to the oldID with the newID. 
*/
Loop, % (elemnode:=y.selectNodes("//elem")).length {
	k := elemnode.item((i:=A_Index)-1)
	k1 := k.getAttribute("id")
	k.setAttribute("id", i)
	Loop, % (elemelems:=y.selectNodes("//elem/option")).length {
		kk := elemelems.item((j:=A_Index)-1)
		If (kk.getAttribute("note") = k1) {
			kk.setAttribute("note", i)
		}
		If (kk.getAttribute("target") = k1) {
			kk.setAttribute("target", i)
		}
	}
	if (opc := k.getAttribute("UID")) {
		z1 := y.selectSingleNode("//elem[@link='" opc "']")
		z1.setAttribute("link", i)
		k.removeAttribute("UID")
		if (z2:=z1.selectSingleNode("option").getAttribute("target")) {
			z1.setAttribute("link", z2)
		}
	}
}
Loop, % (linknode:=y.selectNodes("//elem[@link]")).length {
	k := linknode.item((i:=A_Index)-1)
	if (k1 := k.selectSingleNode("option").getAttribute("target")) {
		k.setAttribute("link", k1)
		; how do I remove an element? Perhaps moot if Algo just skips through links.
	}
}

y.viewXML()

if (strlen(errtext) > 1 ) {			; If there are items in errlog, then show errors, exit.
	MsgBox, 16, Error!, Bad connectors associated with:`n`n%errtext%
}

MsgBox, 260, Save, Create XML file?
IfMsgBox, Yes
{
	y.save(outname)
	MsgBox, XML done!, %outname%
}

ExitApp

/*	Trims "<br>" from edges 
*/
TrimBR(ByRef trimVar)		{
	if (SubStr(trimVar, -3) = "<br>") {
		StringTrimRight trimVar, trimVar, 4
	}
	if (SubStr(trimVar, 1, 4) = "<br>") {
		StringTrimLeft trimVar, trimVar, 4
	}
}

