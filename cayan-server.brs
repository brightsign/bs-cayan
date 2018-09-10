' BrightAuthor Plugin to support Cayan

' Accepted Plugin Message:
' PLACE_ORDER_TIP: message send when user choose checkout, will pop up tip option.
' PLACE_ORDER_CHECKOUT: message send when user choose checkout, will direct to check out.
' CANCEL_ORDER: will cancel order and direct to initial welcome page
' Formatted as command$@@num%:
'   command$ indicates expected action to take
'   @@ is delimiter
'   if command$ is 'tip', num% is tip percentage in two decimal point format
'   if command$ is 'inc_init' or 'inc'or 'dec', num% is id of the item
'     'inc_init' will be used when user want to add an item for the first time of the order.'
'      It will start the screen of line item display on POS.
'     'inc' will be used to add item except the first item in the order.
'     'dec' will be used to decrase the count of an item in the order.

' Accepted JavaScript Message:
' see in function HandleJSMsg(msg, m)

' See more details in README.md



Function cayan_Initialize(msgPort As Object, userVariables As Object, bsp as Object)

  print "================================= cayan_Initialize - entry"

	h = {}
	h.version = "1.0.0"
  print "================================= version:";h.version
	h.msgPort = msgPort
	h.userVariables = userVariables
	h.bsp = bsp
	h.ProcessEvent = cayan_ProcessEvent
	h.objectName = "cayan_object"

  nodePackage = createObject("roBrightPackage", bsp.assetPoolFiles.getPoolFilePath("cayan-plugin.zip"))
  CreateDirectory("cayan-plugin")
  nodePackage.Unpack("cayan-plugin/")

  url$ = "file:///sd:/cayan-plugin/cayan-server.html"

	htmlRect = CreateObject("roRectangle", 0, 0, 1920, 1080)
	is = { port: 2999 }
	config = {
    	nodejs_enabled: true
    	brightsign_js_objects_enabled: true
      url: url$
      port: msgPort
	}
  JSConsoleEnabled = bsp.sign.htmlEnableJavascriptConsole
  if JSConsoleEnabled then
    config.AddReplace("inspector_server", is)
  endif
	h.htmlWidget = CreateObject("roHtmlWidget", htmlRect, config)
  h.htmlWidget.Show()
	return h

End Function

Function cayan_ProcessEvent(event As Object) as boolean
	'Receive a plugin message
    if type(event) = "roAssociativeArray" then
      if type(event["EventType"]) = "roString" then
        if event["EventType"] = "SEND_PLUGIN_MESSAGE" then
          if event["PluginName"] = "cayan" then
            pluginMessage$ = UCase(event["PluginMessage"])
		        if pluginMessage$ = "PLACE_ORDER_TIP" then
              CalculateTip(m)
            else if pluginMessage$ = "PLACE_ORDER_CHECKOUT" then
              PlaceOrder(m)
            else if pluginMessage$ = "CANCEL_ORDER" then
              print "cancel order clicked"
              CancelOrder(m)
            else if pluginMessage$ = "CHECKOUT_TEST_MODIFY_KEY" then
              order% = m.userVariables.ordernumber.getcurrentvalue().toInt()
              m.htmlWidget.PostJSMessage({action:"placeorder_modify_key_error", orderno:order%})
            else if pluginMessage$ = "RETRIEVE_TRANSACTION_DETAIL" then
              m.htmlWidget.PostJSMessage({action:"trans_detail"})
            else
              ParsePluginMsg(pluginMessage$, m)
            endif

            'return true when you want no other event processors to handle this event 
            return true
          endif
        endif
      endif
    'Receive message from html widget
    else if type(event)="roHtmlWidgetEvent" then
      payload = event.GetData()
      eventdata = payload.reason
      if eventdata = "message" then
        message = payload.message
        'print message;"+++++++++++++++++++++++++++++++++++++++++"
        HandleJSMsg(message, m)
      else if eventdata = "load-error" then
        print "=== BS: HTML load error: "; payload.message
      else if eventdata = "load-finished" then
        print "=== BS: Received load finished"
        HandleSettings(m)
      endif
    endif

    'return false if another plugin or event processor should get a chance to handle this event
    return false
End Function


' send cayan required configuration parameters setted by user in BrightAuthor userVariables 
' to JavaScript checking for empty variables and send back error msg if find any
Sub HandleSettings(s as object)
  'print (s.userVariables.abc=invalid)
  mname   = CheckUserVariablesDefined(s, "merchantname")
  msiteid = CheckUserVariablesDefined(s, "merchantSiteId")
  mkey    = CheckUserVariablesDefined(s, "merchantKey")
  address = CheckUserVariablesDefined(s, "POSIPAddress")

  cid             = CheckUserVariablesDefined(s, "clerkId")
  sname           = CheckUserVariablesDefined(s, "softwareName")
  sversion        = CheckUserVariablesDefined(s, "softwareVersion")
  businessname    = CheckUserVariablesDefined(s, "dba")
  tid             = CheckUserVariablesDefined(s, "terminalId")
  taxpercent      = CheckUserVariablesDefined(s, "taxPercentInDecimal")
  initialnetprice = CheckUserVariablesDefined(s, "initialPrice")

  if initialnetprice="" or initialnetprice="''" or initialnetprice=chr(34)+chr(34)
    s.userVariables.initialPrice.setcurrentvalue(0,true)
    initialnetprice = "0"
  endif

  itemcount  = CheckUserVariablesDefined(s, "totalItemCount")
  endpoint   = CheckUserVariablesDefined(s, "transportendpoint")
  
  settings = CreateObject("roAssociativeArray")
  settings = {action:"setting"
              merchantname:mname
              merchantsiteid:msiteid
              merchantkey:mkey 
              posipaddress:address
              softwarename: sname
              softwareversion: sversion
              dba: businessname
              terminalid: tid
              taxpercentindecimal: taxpercent
              initialprice: initialnetprice
              totalitemcount: itemcount
              transportendpoint: endpoint
              }
  
  gendpoint = CheckUserVariablesDefined(s, "geniusendpoint")
  if gendpoint<>"" and gendpoint<>"''" and gendpoint<>chr(34)+chr(34) then
    settings.AddReplace("geniusendpoint", gendpoint)
  endif
  s.htmlWidget.PostJSMessage(settings)

End Sub

Function CheckUserVariablesDefined(s as object, name as string) as string
  result = s.userVariables[name]
  if result = invalid then
    result = ""
  else
    result = result.getcurrentvalue()
  endif
  return result
End Function


' Handle message send from javascript and process accordingly
Sub HandleJSMsg(message as object, s as object)

  'print message;"==================================="
  returnstatus = message.status
  print "=======";returnstatus
  if returnstatus = "reset" then
    ResetCount(s)
    SendZoneMsg("CancelOrder", s)
  else if returnstatus = "error" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, message.errormsg)
    print "errormsg:";message.errormsg
  else if returnstatus = "approved" then
    ResetCount(s)
    SendZoneMsg("OrderComplete", s)
    if message.errormsg = invalid then
      sendPluginEvent(s, "Thank you for your order!")
    else
      sendPluginEvent(s, message.errormsg)
    endif
  else if returnstatus = "failed" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "Payment failed, please try again!")
  else if returnstatus = "declined" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "Payment declined, please try again!")
  else if returnstatus ="declined_duplicate" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "Transaction duplicated!")
  else if returnstatus = "referral" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "Referral error, please see merchant!")
  else if returnstatus = "unkown" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "Unknown error, please try again!")
  else if returnstatus = "usercancelled" then
    SendZoneMsg("TransactionError", s)
    sendPluginEvent(s, "User cancelled, please try again!")
  else if returnstatus = "poscancelled" then
  else if returnstatus = "uservarempty" then
    s.userVariables.message.setcurrentvalue(message.errormsg,true)
  else if returnstatus = "checkingfinished" then
    SendZoneMsg("CheckFinished", s)
  else if returnstatus = "updateTotal" then
    s.userVariables.totalprice.setcurrentvalue(message.price,true)
  else if returnstatus = "updateTenPercentTip" then
    s.userVariables.tenPercentTip.setcurrentvalue(message.price,true)
  else if returnstatus = "updateFifteenPercentTip" then
    s.userVariables.fifteenPercentTip.setcurrentvalue(message.price,true)
  else if returnstatus = "updateTwentyPercentTip" then
    s.userVariables.twentyPercentTip.setcurrentvalue(message.price,true)
  else if returnstatus = "transportKeyUndefined" then
    s.userVariables.message.setcurrentvalue(message.errormsg,true)
    s.htmlWidget.PostJSMessage({action:"cancel"})
  else
    print "Unknown status:";returnstatus
    SendZoneMsg("TransactionError", s)
    s.userVariables.message.setcurrentvalue("Unknown status...",true)
  endif

End Sub

Sub sendPluginEvent(h as object, message as string)
  pluginMessageCmd = CreateObject("roAssociativeArray")
  pluginMessageCmd["EventType"] = "EVENT_PLUGIN_MESSAGE"
  pluginMessageCmd["PluginName"] = "cayan"
  pluginMessageCmd["PluginMessage"] = message
  h.msgPort.PostMessage(pluginMessageCmd)
End Sub


Sub SendZoneMsg(command as string, s as object)
  sendZoneMessageParameter$ = command
  zoneMessageCmd = CreateObject("roAssociativeArray")
  zoneMessageCmd["EventType"] = "SEND_ZONE_MESSAGE"
  zoneMessageCmd["EventParameter"] = sendZoneMessageParameter$
  s.msgPort.PostMessage(zoneMessageCmd)
End Sub


Sub PlaceOrder(s as object)
  order% = s.userVariables.ordernumber.getcurrentvalue().toInt()
  s.htmlWidget.PostJSMessage({action:"placeorder", orderno:order%})
End Sub


Sub CancelOrder(s as object)
  s.htmlWidget.PostJSMessage({action:"cancel"})
  ResetCount(s)
  SendZoneMsg("CancelOrder", s)
End Sub


' set all itemcount to 0
Sub ResetCount(s as object)
  count = s.userVariables.totalItemCount.getcurrentvalue().toInt()
  for i=1 to count step 1
    itemcount$="itemcount"+i.tostr()
		s.userVariables[itemcount$].setcurrentvalue(0,true)
  end for
End Sub


' when plugin msg is different from above string.
' in this case, all strings should be formatted as command$@@num%
' where command$ indicates expected action to take
' if command$ is 'tip', num% is tip percentage in two decimal point format
' if command$ is 'inc' or 'dec', num% is id of the item
Sub ParsePluginMsg(pluginMessage$ as string, s as object)
  msg = lcase(pluginMessage$)
  'print msg
  r2 = CreateObject("roRegex", "@@", "i")
	fields=r2.split(msg)
	numFields = fields.count()
	if numFields = 2 then
    'If we are not processing payment, take action based on passed argument
    command$ = fields[0]
    varNo$ = fields[1]
    if command$="tip" then
      SetTip(command$, varNo$, s)
    else
      ChangeItemValue(command$, varNo$, s)
    endif
	else 
		print "Incorrect number of fields for uservar command$:";msg
  endif

End Sub


' pass user selected tip percentage to JavaScript to do the calculation
' send zone message to transit to next state (transaction processing)
Sub SetTip(command$ as string, varNo$ as string, s as object)
  order%=s.userVariables.ordernumber.getcurrentvalue().toInt()
  if varNo$="0" OR varNo$="0.1" OR varNo$="0.15" OR varNo$="0.2" then
    print "====selected tip"
    print varNo$
    s.htmlWidget.PostJSMessage({action:"tipselected", tippercent:varNo$, orderno:order%})
    SendZoneMsg("StartTransaction", s)
  else
    print "====tip percent undefined"
    s.userVariables.message.setcurrentvalue("Tip percent undefined...",true)
  endif
End Sub


' handle message when user add or substract item from the order
Sub ChangeItemValue(command$ as string, varNo$ as string, s as object)

  changeCount$="itemcount"+varNo$
  currCount%=s.userVariables[changeCount$].getcurrentvalue().toInt()
  itemprice$="itemprice"+varNo$
  itemname="itemname"+varNo$
  itemname$=s.userVariables[itemname].getcurrentvalue()
  order%=s.userVariables.ordernumber.getcurrentvalue().toInt()
  itemprice=s.userVariables[itemprice$].getcurrentvalue()
  totalprice=s.userVariables.totalprice.getcurrentvalue()

  'when increase for the first time of the order
  if command$="inc_init" then
    s.userVariables.ordernumber.increment()
    order%=s.userVariables.ordernumber.getcurrentvalue().toInt()
    'start line item up
    s.htmlWidget.PostJSMessage({action:"start", orderno:order%})
    'add default item, if any
    initialprice%=s.userVariables.initialPrice.getcurrentvalue().toFloat()
    if initialprice% <>0
      initialitemname=s.userVariables.initialitemname.getcurrentvalue()
      initialprice=s.userVariables.initialPrice.getcurrentvalue()
      itemupc="initialitemupc"
      itemupcobj=s.userVariables[itemupc]
      if itemupcobj=invalid then
        s.htmlWidget.PostJSMessage({action:"additem", orderno:order%, itemid:0, name:initialitemname, amount:initialprice})
      else
        itemupc=itemupcobj.getcurrentvalue()
        s.htmlWidget.PostJSMessage({action:"additem", orderno:order%, itemid:0, name:initialitemname, amount:initialprice, upc:itemupc})
      endif
    endif
    'add the user selected item
    AddItem(changeCount$, itemprice, order%, varNo$, itemname$, currCount%, s)
  'increase item count
  else if command$="inc" then
    AddItem(changeCount$, itemprice, order%, varNo$, itemname$, currCount%, s)
  'decrease item count
  else if command$="dec" then
    if currCount%>0 then
      currCount% = currCount% - 1
      'print currCount%
      totalprice=s.userVariables.totalprice.getcurrentvalue()
      s.userVariables[changeCount$].setcurrentvalue(currCount%,true)
      s.htmlWidget.PostJSMessage({action:"calculation", operator: "substract",price: itemprice})
      if currCount%=0 then
        s.htmlWidget.PostJSMessage({action:"deleteitem", orderno:order%, itemid:varNo$})
        totalCount = CheckTotalCount(s)
        if totalCount = 0 then
          SendZoneMsg("DisablePlaceOrderTip", s)
        endif
      else
        s.htmlWidget.PostJSMessage({action:"updateitem", orderno:order%, itemid:varNo$, count:currCount%})
      endif
    endif
  endif
End Sub


' check current total count of the items in the order
' used for hiding checkout button when count=0 in line item display 
Function CheckTotalCount(s as object)
  total = 0
  count = s.userVariables.totalItemCount.getcurrentvalue().toInt()
  for i=1 to count step 1
    itemcount$="itemcount"+i.tostr()
		total = total + s.userVariables[itemcount$].getcurrentvalue().toInt()
  end for
  return total
End Function


' add item in line item up display
Sub AddItem(changeCount$ as string, itemprice as string, order% as integer, varNo$ as string, itemname$ as string, currCount% as integer, s as object)
  SendZoneMsg("EnablePlaceOrderTip", s)
  s.userVariables[changeCount$].increment()
  s.htmlWidget.PostJSMessage({action:"calculation", operator: "add", price: itemprice})
  if currCount%=0 then
    itemupcname="itemupc"+varNo$
    itemupcobj=s.userVariables[itemupcname]
    print itemupcobj;"+++++++++"
    if itemupcobj=invalid then
      s.htmlWidget.PostJSMessage({action:"additem", orderno:order%, itemid:varNo$, name:itemname$, amount:itemprice})
    else
      itemupc=itemupcobj.getcurrentvalue()
      s.htmlWidget.PostJSMessage({action:"additem", orderno:order%, itemid:varNo$, name:itemname$, amount:itemprice, upc:itemupc})
    endif
  else
    s.htmlWidget.PostJSMessage({action:"updateitem", orderno:order%, itemid:varNo$, count:currCount%+1})
  endif
End Sub


' send tip percentage to JavaScript and get back to display
Sub CalculateTip(s as object)
  totalprice=s.userVariables.totalprice.getcurrentvalue()
  s.htmlWidget.PostJSMessage({action:"calculation", operator: "multiply", tip: "0.1"})
  s.htmlWidget.PostJSMessage({action:"calculation", operator: "multiply", tip: "0.15"})
  s.htmlWidget.PostJSMessage({action:"calculation", operator: "multiply", tip: "0.2"})
End Sub
