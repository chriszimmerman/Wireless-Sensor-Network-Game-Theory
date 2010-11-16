// This file has been modified by Chris Zimmerman.
// This file, along with the other original AntiTheft application code
// can be found at tinyos.net 

// $Id: AntiTheftC.nc,v 1.7 2009/10/28 19:11:15 razvanm Exp $
/*
 * Copyright (c) 2007 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/**
 * Main code for the anti theft demo application.
 *
 * @author David Gay
 */
#include "antitheft.h"

module AntiTheftC
{
  uses {
    interface Timer<TMilli> as Check;
    interface Timer<TMilli> as BlacklistSleep;
    interface Leds;
    interface Boot;
    interface DisseminationValue<settings_t> as SettingsValue;
    interface StdControl as CollectionControl;
    interface StdControl as DisseminationControl;
    interface SplitControl as RadioControl;
    interface LowPowerListening;
    interface Read<uint16_t> as BatteryLevel;
    interface AMSend as TheftSend;
    interface Receive as TheftReceive;
  }
}
implementation
{
  enum {
    /* A battery with voltage below this level is conisdered low on power */
    BATTERY_THRESHOLD = 300, 

    /* Amount of time node "goes to sleep" (turns its radio off) for. */
    SLEEP_TIME = 10000,

    /* Amount of time warning leds should stay on (in checkInterval counts) */
    WARNING_TIME = 3,

  };

  settings_t settings; 
  message_t alertMsg, theftMsg, fwdMsg;
  uint16_t ledTime; /* Time left until leds switched off */
  uint16_t currentVolt; /* Current voltage read by the sensor node */
  bool fwdBusy; /* Indicates whether or not the node is busy forwarding a packet. */

  /********* LED handling **********/

  /* Warn that some error occurred */
  void errorLed() {
    ledTime = WARNING_TIME;
    call Leds.led2On();
  }

  /* Notify user that settings changed */
  void settingsLed() {
    ledTime = WARNING_TIME;
    call Leds.led1On();
  }

  /* Turn on bright red light! (LED) */
  void theftLed() {
    ledTime = WARNING_TIME;
    call Leds.led0On();
  }

  /* Time-out leds. Called every checkInterval */
  void updateLeds() {
    if (ledTime && !--ledTime)
      {
	call Leds.led0Off();
	call Leds.led1Off();
	call Leds.led2Off();
      }
  }

  /* Check result code and report error if a problem occurred */
  void check(error_t ok) {
    if (ok != SUCCESS)
      errorLed();
  }

  /* At boot time, start the periodic timer and the radio */
  event void Boot.booted() {
    errorLed();
    settings.alert = DEFAULT_ALERT;
    settings.detect = DEFAULT_DETECT;

    call Check.startPeriodic(DEFAULT_CHECK_INTERVAL);
    call RadioControl.start();
  }

  /* Radio started. Now start the collection protocol and set the
     wakeup interval for low-power-listening wakeup to half a second. */
  event void RadioControl.startDone(error_t ok) {
    if (ok == SUCCESS)
      {
	call DisseminationControl.start();
	call CollectionControl.start();
	call LowPowerListening.setLocalWakeupInterval(512);
      }
    else
      errorLed();
  }

  /* The radio has shut down, so shut down the dissemination and
     collection controls and start the blacklist timer. */
  event void RadioControl.stopDone(error_t ok) 
  { 
  	call DisseminationControl.stop();
	call CollectionControl.stop();
        call BlacklistSleep.startOneShot(settings.duration);
  }

  /* The blacklist time period has expired, so start the radio again. */
  event void BlacklistSleep.fired()
  {
	call RadioControl.start();
  }

  /* New settings received, update our local copy */
  event void SettingsValue.changed() {
    const settings_t *newSettings = call SettingsValue.get();

    settingsLed();
    settings = *newSettings;

    /* If this is a node we want to blacklist, stop the radio
       for the duration specified in the packet. */
    if(TOS_NODE_ID == newSettings->targetId)
    {
	call RadioControl.stop();
    } 

    /* Switch to the new check interval */
    call Check.startPeriodic(newSettings->checkInterval);
  }

  /* Every check interval: update leds, check for low battery 
     based on current settings */
  event void Check.fired() 
  {
    updateLeds();

    if (settings.detect & LOW_BATTERY && fwdBusy == FALSE)
    {
      call BatteryLevel.read();
    }
  }

  /* Send packets to the base node, based on current settings */
  void blacklist() 
  {
    if (settings.alert & BROADCAST) //The "Broadcast" checkbox must be checked to broadcast
    {				      //a packet through the network.
	if(!fwdBusy)
    	{	
		alert_t *fwdAlert = call TheftSend.getPayload(&theftMsg, sizeof(alert_t));
	
		if(fwdAlert != NULL)
		{		
			//fill in all of the data members of the packet
			fwdAlert->stolenId = TOS_NODE_ID;
			fwdAlert->voltageData = currentVolt;
			fwdAlert->packetId = TOS_NODE_ID;
			fwdAlert->path1 = TOS_NODE_ID;
			fwdAlert->path2 = 999;
			fwdAlert->path3 = 999;
			fwdAlert->path4 = 999;
			fwdAlert->path5 = 999;
			fwdAlert->path6 = 999;
			fwdAlert->ignoredId = TOS_NODE_ID;

			call Leds.led1On();

			if(call TheftSend.send(AM_BROADCAST_ADDR, &theftMsg, sizeof *fwdAlert) == SUCCESS)
				fwdBusy = TRUE;
		}    
	}
	
    }	
      
  }

  /* Battery level reading completed. Check if it's a low battery. */
  event void BatteryLevel.readDone(error_t ok, uint16_t val)
  {
	currentVolt = val;
	blacklist();

  }



  /* We've received a blacklist packet from a neighbor. Forward it through the network
     to the base station. */

  event message_t *TheftReceive.receive(message_t* msg, void* payload, uint8_t len) 
  {
    alert_t *newAlert = payload;
    if(len == sizeof(*newAlert) && !fwdBusy)
    {
	alert_t *fwdAlert = call TheftSend.getPayload(&fwdMsg, sizeof(alert_t));
	if(fwdAlert != NULL)
	{
		*fwdAlert = *newAlert;
		//This prevents flooding & cycling.
		//If this node's ID is in the routing path, it's cycling, so just drop the packet.
		if((fwdAlert->path6 == TOS_NODE_ID) ||
		   (fwdAlert->path5 == TOS_NODE_ID) ||
                   (fwdAlert->path4 == TOS_NODE_ID) ||
                   (fwdAlert->path3 == TOS_NODE_ID) ||
                   (fwdAlert->path2 == TOS_NODE_ID) ||
                   (fwdAlert->path1 == TOS_NODE_ID))
		;
		else //Otherwise, add the current node ID to the front of the route path and send the packet.
		{
			fwdAlert->path6 = fwdAlert->path5;
			fwdAlert->path5 = fwdAlert->path4;
			fwdAlert->path4 = fwdAlert->path3;
			fwdAlert->path3 = fwdAlert->path2;
			fwdAlert->path2 = fwdAlert->path1;
			fwdAlert->path1 = TOS_NODE_ID;

			if(call TheftSend.send(AM_BROADCAST_ADDR, &fwdMsg, sizeof(alert_t)) == SUCCESS)
				fwdBusy = TRUE;
		}
	}
    }
    return msg;
  }
  
  //The packet has been sent, so the node is no longer busy.
  event void TheftSend.sendDone(message_t *msg, error_t error)
  {
	//if(msg == &fwdMsg)
		fwdBusy = FALSE;
  }


}
