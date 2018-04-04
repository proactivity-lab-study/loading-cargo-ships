#include "comm.h"
#include "game_types.h"

module SystemCommunicationP
{
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
	
	provides interface SysLink;
	provides interface CraneLink;
	provides interface StdControl as SendWelcomeMsg;
}
implementation 
{
	message_t pkt;
	bool busy = FALSE;

	/************************************************************
	 *	Start everything by sending welcome message
	 ************************************************************/

	command error_t SendWelcomeMsg.start()
	{
		if(!busy)
		{
			queryMsg* qMsg = (queryMsg*)(call Packet.getPayload(&pkt, sizeof(queryMsg)));
			if (qMsg == NULL)
			{
				return FAIL;
			}

			qMsg->messageID = WELCOME_MSG;
			qMsg->senderID = TOS_NODE_ID;

			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
		}
		else return EBUSY;
		return FAIL;
	}

	command error_t SendWelcomeMsg.stop(){return FAIL;}//command not used

	task void simulateSendWelcome()//for test only
	{
		//instead of sending message we are hardcoding a fake response
		//to the welcome message instead, in order to test the system
		message_t pkt2;

		queryResponseMsg* qMsg = (queryResponseMsg*)(call Packet.getPayload(&pkt2, sizeof(queryResponseMsg)));
		if (qMsg == NULL)
		{
			return ;
		}
		qMsg->messageID = WELCOME_RMSG;
		qMsg->senderID = SYSTEM_ID;
		qMsg->shipID = TOS_NODE_ID;
		qMsg->departureT = 452;
		qMsg->x_coordinate = 62;
		qMsg->y_coordinate = 117;
		qMsg->isCargoLoaded = FALSE;
		signal SysLink.responseMsg(qMsg);
	}

	/************************************************************
	 *	Send messages
	 ************************************************************/
	
	command error_t SysLink.makeShipQuiery(uint8_t shipID)
	{
		if (!busy)
		{
			queryMsg* qMsg = (queryMsg*)(call Packet.getPayload(&pkt, sizeof(queryMsg)));
			if (qMsg == NULL)
			{
				return FAIL;
			}
			qMsg->messageID = SHIP_QMSG;
			qMsg->senderID = TOS_NODE_ID;
			qMsg->shipID = shipID;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
		}
		else return EBUSY;
		return FAIL;
	}

	command error_t SysLink.makeAllShipIDQuiery(uint8_t len)
	{
		if (!busy)
		{
			queryMsg* qMsg = (queryMsg*)(call Packet.getPayload(&pkt, sizeof(queryMsg)));
			if (qMsg == NULL)
			{
				return FAIL;
			}
			qMsg->messageID = AS_QMSG;
			qMsg->senderID = TOS_NODE_ID;
			qMsg->shipID = len;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
		}
		else return EBUSY;
		return FAIL;
	}

	command error_t SysLink.makeAllShipCargoQuiery()
	{
		if (!busy)
		{
			queryMsg* qMsg = (queryMsg*)(call Packet.getPayload(&pkt, sizeof(queryMsg)));
			if (qMsg == NULL)
			{
				return FAIL;
			}
			qMsg->messageID = ACARGO_QMSG;
			qMsg->senderID = TOS_NODE_ID;
			qMsg->shipID = 0;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
		}
		else return EBUSY;
		return FAIL;
	}

	command error_t SysLink.makeGlobalTimeQuiery()
	{
		if (!busy)
		{
			queryMsg* qMsg = (queryMsg*)(call Packet.getPayload(&pkt, sizeof(queryMsg)));
			if (qMsg == NULL)
			{
				return FAIL;
			}
			qMsg->messageID = GTIME_QMSG;
			qMsg->senderID = TOS_NODE_ID;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
		}
		else return EBUSY;
		return FAIL;
	}

	event void AMSend.sendDone(message_t* msg, error_t err)
	{
		if (&pkt == msg) 
		{
			busy = FALSE;
		}
	}

	/************************************************************
	 *	Receive messages
	 ************************************************************/

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		//we must determine whether this is a all ship IDs response message and 
		//treate this message separately, because it has a changing length

		uint8_t *pl = (uint8_t*)payload;
		uint8_t num_ships, i;
		uint8_t sID[MAX_SHIPS];

		

		//now check the value of the first byte of the payload
		if(*pl == AS_QRMSG)//this is a all ship IDs message
		{
			if(*(pl+1) == SYSTEM_ID)
			{
				if(*(pl+2) == TOS_NODE_ID)
				{
					//get number of ships
					num_ships = *(pl+3);
					if(num_ships <= MAX_SHIPS)for(i=0;i<num_ships;i++)
					{
						sID[i] = *(pl+4+i);
					}
					signal SysLink.ships(num_ships, sID);
				}
			}
		}
		else if(*pl == ACARGO_QRMSG)//this is a all ships with cargo message
		{
			if(*(pl+1) == SYSTEM_ID)
			{
				if(*(pl+2) == TOS_NODE_ID)
				{
					//get number of ships
					num_ships = *(pl+3);
					if(num_ships <= MAX_SHIPS)for(i=0;i<num_ships;i++)
					{
						sID[i] = *(pl+4+i);
					}
					signal SysLink.cargoLoaded(num_ships, sID);
				}
			}
		}
		else
		{
			if (len == sizeof(queryResponseMsg))
			{
				queryResponseMsg* resMsg = (queryResponseMsg*)payload;
				signal SysLink.responseMsg(resMsg);
			}
			else ;
		}
		return msg;
	}

	command error_t CraneLink.send_command(uint8_t cmd)
	{
		return FAIL;
	}

	default event void SysLink.responseMsg(queryResponseMsg *rmsg){}
	default event void SysLink.ships(uint8_t num_ships, uint8_t sID[]){}
}