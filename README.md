# BrightAuthor Presentation Demo for Cayan


## Description:
This project includes a BrightAuthor plugin and example presentation. The plugin sends information to (and receives information from) the Cayan Cloud and a Genius POS unit to complete transactions.


## User Variables: 
* The following are user variables used by the plugin to communicate and display transaction information.
* All variables are required except for the ones marked as optional.

1. itemname[n], itemcount[n], itemprice[n], itemupc[n]

	* These values represent items on the menu, and [n] indicates the item ID. 
 
	* For example, the first item in the menu
will have an ID of 1, and it will have these values associated with it: itemname1, itemcount1, itemprice1 (,itemupc1).

	* When creating IDs for your menu items, the first item ID must start at 1 and increase by 1 every time (so that the highest item ID value will equal the value of the totalItemCount variable).

 	```
 	itemname[n]: The name of the item.

 	itemcount[n]: The number of units of the item in the current order.

 	itemprice[n]: The price of a single unit of the item.

 	itemupc[n]:(optional) The UPC (universal product code) of the item.
 	
 	```

2. totalprice

	* The total order price (including tax and tip). If you want a default item added to every order, set this variable to the price of that item (after tax). If not, set it to 0.

3. initialPrice

	* The initial order price. If you want a default item added to every order, set this variable to the price of that item (before tax). If not, set it to 0.

4. message

	* The message to display on screen. The value of this variable will change depending on events and errors received from the plugin. 

5. ordernumber

	* The order number of the current transaction. This value will automatically increment and is usually set to 0 as the initial value.

6. tenPercentTip, fifteenPercentTip, twentyPercentTip

	* These variables are used to display the tip price after calculating different tip precentages. These values should be set to 0. They will be generated at the tip state.

7. totalItemCount
 
	* The total amount of items in the presentation. This value should equal the highest item ID in the presentation. This variable is used to iterate on every item during the reset step.

8. initialitemname (optional)

	* The name of the default item added to every order. If do not have a default item, this variable does not need to be part of the presentation.

9. taxPercentInDecimal

	* The tax percentage of the location. The tax for all items will be calculated using this variable. The percentage must be specified as a decimal value: For example, if the tax percentage is 10%, then set the variable to be 0.1.

10. merchantName

	* The name of the business or organization that owns the Merchantware account.

11. merchantSiteId

	* The site identifier of the location or storefront owned by the Merchantware account owner.

12. merchantKey

	* The software key or password for the site accessing the Merchantware account.

13. POSIPAddress

	* The IP Address of the Cayan POS. We recommend using a static IP Address.

14. softwareName

	* The name of the software application sending the request. 

15. softwareVersion

	* The version number of the software application sending the request.

16. dba

	* The business name of the merchant as it should appear to the customer.

17. terminalId

	* The terminal ID, which is used to uniquely identify the terminal to the processor. This value must contain all numeric characters. If no value is supplied, the last two digits of the Genius-device serial number will be used as a default value.

18. transportendpoint

	* The transport endpoint URL, which is most commonly set to https://transport.merchantware.net/v4/transportService.asmx
The CED-HOSTNAME is the POS IP Address.

19. geniusendpoint(optional)

	* The Genius endpoint URI. The default endpoint is formatted as http://[CED-HOSTNAME]:8080/v2/pos?

	* The CED-HOSTNAME is the POS IP Address. If you are using a different endpoint, put the uri in this variable. Otherwise, do not add this variable.



## Presentation Workflow:
### State0: Check user variables settings

* if all variables meet requirements (see userVariables section) -> transit to state1 (zone message: CheckFinished)
* else -> display an error message (which is automatically set by BrightScript)
* Message: 
	* Check setting…
	* [uservariable] cannot be empty! 

### State1: Welcome Page
* Enabled button(s): 
	* add item
* Change state trigger(s): 
	* User adds the first item (send plugin msg: inc\_init@@[itemid]) -> transit to state2
* Message: 
	* Welcome to build-a-burger! (Set at entry to this state)

### State2: Modify Order
* Enabled button(s): 
	* add item, minus item, place order, cancel order
	* (zone message: EnablePlaceOrderTip, EnableCancelOrder)
* Change state trigger(s): 
	* Select place order -> transit to state3 (zone message: ChooseTip)
	* Select cancel order -> show cancel confirmation zone (zone message: EnableCancelConfirm) -> transit to state1 (zone message: CancelOrder) or return to current state
* Message: 
	* Select your burger items! (Set at entry to this state)

### State3: Tip 
* Enabled button(s): 
	* Four tip zones, cancel order (zone message: EnableCancelOrderTip)
* Change state trigger(s): 
	* Any one of the tip zones selected -> transit to state4, start transaction process (zone message: StartTransaction)
	* Select cancel order -> show cancel confirmation zone(zone message: EnableCancelConfirmTip) -> transit to state1 (zone message: CancelOrder) or return to current state
* Message: 
	* Please select tip amount: (Set at entry of this state)

### State4: Order In Progress 
* Enabled button(s): 
	* cancel order, display “Processing...” message
* Change state trigger(s): 
	* POS sends over error message -> transit to state5 (zone message: TransactionError)
	* POS sends over “approved message” -> transit to state6 (zone message:  OrderComplete)
	* Select cancel order->show cancel confirmation zone(zone message:EnableCancelConfirm) -> transit to state1 (zone message: CancelOrder) or return to current state
* Message: 
	* Processing... (Set at entry of this state)
	* Thank you for your order! (Set by BrightScript)

### State5: Transaction Error
* Enabled button(s): 
	* Place order, cancel order, display error message
* Change state trigger(s): 
	* Select place order -> transit to state4, start transaction process 
	(zone message: PlaceOrderAgain)
	* Select cancel order -> show cancel confirmation zone (zone message: EnableCancelConfirm) -> transit to state1 (zone message: CancelOrder) or return to current state
* Message: 
	* Different error msgs are displayed depending on POS response

### State6: Order Complete
* Display the order complete message.
* Will automatically transit to state1 after timeout.


## Zone Messages:
1. Main background zone
	* CheckFinished: check\_setting -> welcome\_page,
	* ChooseTip: modify\_order -> tip,
	* StartTransaction: tip -> order\_in\_progress,
	* TransactionError: order\_in\_progress -> transaction\_error,
	* OrderComplete: order\_in\_progress -> order\_complete,
	* CancelOrder: (modify\_order, tip, order\_in\_progress, transaction\_error) -> welcome\_page

2. Item count zone
	* REFRESH: Transition to itself as a new state (refresh the display of userVariables)

3. Total price
	* REFRESH: Transition to itself as a new state (refresh the display of userVariables)

4. Tipzone1, Tipzone2, Tipzone3, Tipzone4
	* ENABLETIP: transparent -> tipzone[n] (display the tip zone),
	* DISABLETIP: tipzone[n] -> transparent (disable the tip zone)

5. Place order button
	* EnablePlaceOrderTip: transparent -> connect\_to\_tip,
	* DisablePlaceOrderTip: connect\_to\_tip ->transparent,
	* EnablePlaceOrderCheckout: transparent -> connect\_to\_checkout,
	* DisablePlaceOrderCheckout: connect\_to\_checkout -> transparent

6. Cancel order button
	* EnableCancelOrder: transparent -> cancel\_order,
	* DisableCancelOrder: cancel\_order -> transparent,
	* EnableCancelOrderTip: transparent -> cancel\_order\_tip,
	* DisableCancelOrderTip: cancel\_order\_tip -> transparent

7. Cancel confirm
	* EnableCancelConfirm: transparent -> cancel\_confirmation,
	* EnableCancelConfirmTip: transparent ->cancel\_confirmation\_tip

