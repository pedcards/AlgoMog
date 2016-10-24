/*	ALGAE transmogrifier, (C) TC 2013
	Tool for converting XML files into $elem() array blocks for use in ALGAE
	scripts.
	ALGAE = Algorithm Logic Graphical Application Encoder
	
	Ver 0.1 (5/22/13) - real basics.
    (5/24/13) - XML support in AHK is challenging. Using Skan's StrX() to parse around XML tags. Serves the purpose for the simple XML files created by draw.io, but could be generalized into function that seeks out child nodes. Also could read node name between "<" and first " ", then use that to seek closing "</xxx>". Create variable to track child levels. Recurse for each child node until done. Check attributes for each node. Is this actually easier than using the COM method?
    (5/26/13) - Will parse the draw.io XML file for relevant attributes. Builds array to fill in nodes and associated connectors, creates list of nodes generated. Terminator blocks still undecided; are they even necessary? Also, how to generate the parent pointers? Will need to run through the nodelist to generate the final text block.
    Ver 0.9 (5/27/13) - Reads XML file. Converts to indexed nodes. Remaps node numbers sequentially (must remap option pointers). Works with simple test file. Have not tried with more complex example. Parent pointer may be redundant if can just go back a page. Will need to redo ALGAE handling of terminator blocks. Is there a better way to get the index number from the right?

*/

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; Get the XML file generated by http://draw.io
FileSelectFile, filename,,, Select XML file:, *.xml
FileRead, xmlfile, %filename%
elemArray := Object()
elemAssoc := Object()
elemCount := 0

N:=1
While xmlfile {
  n0 := N   ; pointer at start of loop, as N is moved for each mxCell call
  mxCell  := StrX( xmlfile, "<mxCell " ,N,0, ">" ,1,0, N )
  if (mxCell = "") {
    break   ; end of xmlfile reached
  }
  if (SubStr(mxCell, -1) = "/>") {
    continue    ; single tag "<mxCell .. />", repeat next loop
  } else {
    N := n0     ; reset counter and parse entire <mxCell> node
    mxCell := StrX( xmlfile, "<mxCell " ,N,0, "</mxCell>" ,1,0, N ) 
    mxID    := StrX( mxCell, "id=" ,1,4, """" ,1,1 )
    mxParent := StrX( mxCell, "parent=" ,1,8, """" ,1,1 )
    mxStyle := StrX( mxCell, "style=" ,1,7, ";" ,1,1 )
    mxValue := StrX( mxCell, "value=" ,1,6, """" ,1,0 )
    StringReplace , mxValue, mxValue, &#xa;, <br>, ReplaceAll   ; draw.io uses &#xa; for CR/LF
    mxSource := StrX( mxCell, "source=" ,1,8, """" ,1,1 )
    mxTarget := StrX( mxCell, "target=" ,1,8, """" ,1,1 )
  }

;   Put element into a variable array.
/*  Elements are in order of creation, not necessarily related to logic, so will fill out components as they arrive. 
    elemArray[x,y,z]
      X = parent
      Y = index
      Z = element
        1 = go back pointer
        2 = display text
        3 = option block. Append arrows elemArray[mxParent,mxSource,3] = mxTarget, mxValue
    Find connectors, termination blocks, and everything else.
    Eventually will need to convert array elements into a final block of text.
*/
  IfInString, mxStyle, endArrow   ; Find and arrow connector
  {
    If ((mxSource = "") or (mxTarget = "")) {
      linerr := mxSource . mxTarget
      boxerr := elemArray[mxParent, linerr ,2]
      MsgBox , , Diagram ERROR, Broken link at`nNode %linerr%:`n`n%boxerr%
      Exit
    } else {
      elemArray[mxParent,mxSource,3] .= mxValue . ", " . mxTarget . ", `n"
      elemArray[mxParent,mxTarget,1] := mxSource
    }
  } 
/*  else IfInString, mxStyle, terminator
    ; Find connector that references this ID as mxTarget and add to that option block.
    ; Or could change ALGAE logic to jump to this as a normal node, and add buttons for completion.
  {
    elemArray[mxParent,mxID,1] := "0"
    elemArray[mxParent,mxSource,3] := mxValue
  } 
*/
  else     ; Everything else, i.e. Display/decision nodes
  {
    elemCount := elemCount + 1
    elemTitle := ""
    IfInString, mxValue, :<br>      ; Parse for title, delimited by ":&#xa;", now converted to ":<br>"
    {
      elemTitle := StrX( mxValue ,"""",1,1, ":<br>" , 1,5 )
      mxValue := """" . StrX( mxValue , ":<br>",1,5, """" ,1,0 )
    }
    elemArray[mxParent,mxID,2] := """" . elemTitle . """, " . mxValue
    elemNodes .= mxParent . ", " . mxID . ", " . elemCount . "`n"
    elemAssoc[mxID] := elemCount
  }
}

; Convert the elemNodes into formatted block of text
elemBlock := ""
Loop, parse, elemNodes, `n
  {
  N := 1
  elemLine := A_LoopField
  If (elemLine = "") {
    break
  }
  elemParent := StrX(elemLine, "", N,0, "," ,1,1, N )
  elemIndex := StrX(elemLine, "," ,N,2, "," ,1,1, N )
  elemBlock2 := elemArray[elemParent,elemIndex,3]
  elemBlock3 := ""
  Loop, Parse, elemBlock2, `n
    {
    blockline := A_LoopField
    oldnum := StrX( blockline, "," ,0,-2, "," ,1,1 )
    newnum := elemAssoc[oldnum]
    StringGetPos , leftpos, blockline, `, , R , 3
    leftpos := leftpos + 2
    StringLeft , leftstr, blockline , leftpos
    elemBlock3 .= leftstr . newnum . ",`n"
    }
  elemBlock .= "$elem[" . elemParent . "][" . elemAssoc[elemIndex] . "] = array(" . elemAssoc[elemArray[elemParent,elemIndex,1]] . ", " . elemArray[elemParent,elemIndex,2] . ", `n" . SubStr(elemBlock3, 1, -4) . ");`n"
  }

MsgBox ,, Array, %elemBlock%

/* StrX ( H, BS,BO,BT, ES,EO,ET, NextOffset )
*/
StrX( H,  BS="",BO=0,BT=1,   ES="",EO=0,ET=1,  ByRef N="" ) { ;    | by Skan | 19-Nov-2009
Return SubStr(H,P:=(((Z:=StrLen(ES))+(X:=StrLen(H))+StrLen(BS)-Z-X)?((T:=InStr(H,BS,0,((BO
 <0)?(1):(BO))))?(T+BT):(X+1)):(1)),(N:=P+((Z)?((T:=InStr(H,ES,0,((EO)?(P+1):(0))))?(T-P+Z
 +(0-ET)):(X+P)):(X)))-P) ; v1.0-196c 21-Nov-2009 www.autohotkey.com/forum/topic51354.html
}
