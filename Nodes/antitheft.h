// This file has been modified by Chris Zimmerman.
// This file, along with the other original AntiTheft application code
// can be found at tinyos.net 

// $Id: antitheft.h,v 1.3 2007/04/04 22:06:22 idgay Exp $
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
 *
 * @author David Gay
 */
#ifndef ANTITHEFT_H
#define ANTITHEFT_H

enum {
  BROADCAST = 4,

  LOW_BATTERY = 1,

  AM_SETTINGS = 54,
  AM_THEFT = 99,
  AM_ALERT = 22,
  DIS_SETTINGS = 42,
  COL_ALERTS = 11,

  DEFAULT_ALERT = BROADCAST,
  DEFAULT_DETECT = LOW_BATTERY,
  DEFAULT_CHECK_INTERVAL = 1000
};

typedef nx_struct settings {
  nx_uint8_t alert, detect;
  nx_uint16_t checkInterval; //interval for which the nodes check to send packets
  nx_uint16_t targetId; //node we are targeting to be blacklisted
  nx_uint16_t duration; //duration for the target node to be blacklisted
} settings_t;

typedef nx_struct alert {
  nx_uint16_t stolenId;
  nx_uint16_t voltageData; //voltage reading from node
  nx_uint16_t packetId; //unique ID of each reading so we can separate the individual packets at a later date
  nx_uint16_t path1; //last node routed through (last hop)
  nx_uint16_t path2; //2nd to last node routed through (2nd to last hop) 
  nx_uint16_t path3; //..
  nx_uint16_t path4; //..
  nx_uint16_t path5; //..
  nx_uint16_t path6; //6th to last node routed through
  nx_uint16_t ignoredId; //any node(s) that the sending node has blacklisted
} alert_t;

#endif
