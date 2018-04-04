#include "comm.h"
#include "game_types.h"

module SystemCommunicationP
{
	uses interface Leds;
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
	uses interface SysLink2;
}
implementation 
{
	#define MAX_SC_RQL 5 //length of receive queue
	
	
	typedef struct recQ {
		uint8_t sID;//ship
		uint8_t senderID;
		uint8_t request;
	}recQ;

	recQ receiveQueue[MAX_SC_RQL];
	int8_t recQ_index = 0;

	bool busy = FALSE;

	void sendResBuf(uint8_t msgID, uint8_t destination, uint8_t ships[], uint8_t l);
	void sendRes(uint8_t msgID, uint8_t destination, uint8_t x, uint8_t y, uint8_t dt, bool isCargoLoaded);

	task void sendResponse()
	{
		uint8_t locx = DEFAULT_LOC, locy = DEFAULT_LOC;
		uint16_t dTime = DEFAULT_TIME;
		uint8_t ships[MAX_SHIPS], len;
		bool isCL = FALSE;
		error_t err;

		if(busy) //if radio isn't free for send, wait until it is
		{
			post sendResponse();
			return ;
		}

		recQ_index--;
		switch(receiveQueue[recQ_index].request)
		{
			case WELCOME_MSG:
			call Leds.led2On();
			err = call SysLink2.registerNewShip(receiveQueue[recQ_index].senderID);
			if(err == SUCCESS)
			{
				call SysLink2.getShipInfo(receiveQueue[recQ_index].senderID, &locx, &locy, &dTime, &isCL);
				sendRes(WELCOME_RMSG, receiveQueue[recQ_index].senderID, locx, locy, dTime, isCL);
			}
			else ; //lets hope the ships sends welcome msg once more
			break;

			case GTIME_QMSG:
			dTime = call SysLink2.getGlobalTime();
			sendRes(GTIME_QRMSG, receiveQueue[recQ_index].senderID, DEFAULT_LOC, DEFAULT_LOC, dTime, FALSE);
			break;

			case SHIP_QMSG:
			call SysLink2.getShipInfo(receiveQueue[recQ_index].sID, &locx, &locy, &dTime, &isCL);
			sendRes(SHIP_QRMSG, receiveQueue[recQ_index].sID, locx, locy, dTime, isCL);
			break;

			case AS_QMSG:
			call SysLink2.getAllShips(ships, &len);
			sendResBuf(AS_QRMSG, receiveQueue[recQ_index].senderID, ships, len);
			break;

			case ACARGO_QMSG:
			call SysLink2.getAllCargo(ships, &len);
			sendResBuf(ACARGO_QRMSG, receiveQueue[recQ_index].senderID, ships, len);
			break;

			default: break;//do nothing, exept drop this response
		}
		
		if(recQ_index > 0)post sendResponse();
		else recQ_index = 0;//just in case it becomes negative
	}

	/************************************************************
	 *	Send messages
	 ************************************************************/
	message_t pkt;
	
	void sendRes(uint8_t msgID, uint8_t destination, uint8_t x, uint8_t y, uint8_t dt, bool isCargoLoaded)
	{
		if(!busy)
		{
			queryResponseMsg* qRMsg = (queryResponseMsg*)(call Packet.getPayload(&pkt, sizeof(queryResponseMsg)));
			if (qRMsg == NULL)
			{
				return ;
			}

			switch(msgID)
			{
				case WELCOME_RMSG:

				qRMsg->messageID = WELCOME_RMSG;
				qRMsg->senderID = SYSTEM_ID;
				qRMsg->shipID = destination;
				qRMsg->departureT = dt;
				qRMsg->x_coordinate = x;
				qRMsg->y_coordinate = y;
				qRMsg->isCargoLoaded = isCargoLoaded;
				break;

				case GTIME_QRMSG:

				qRMsg->messageID = GTIME_QRMSG;
				qRMsg->senderID = SYSTEM_ID;
				qRMsg->shipID = destination;
				qRMsg->departureT = dt;
				qRMsg->x_coordinate = DEFAULT_LOC;
				qRMsg->y_coordinate = DEFAULT_LOC;
				qRMsg->isCargoLoaded = FALSE;
				break;

				case SHIP_QRMSG:
				
				qRMsg->messageID = SHIP_QRMSG;
				qRMsg->senderID = SYSTEM_ID;
				qRMsg->shipID = destination;//here destination actually means the ID of the ship that the info request was about
				qRMsg->departureT = dt;
				qRMsg->x_coordinate = x;
				qRMsg->y_coordinate = y;
				qRMsg->isCargoLoaded = isCargoLoaded;
				break;

				default:
				break;
			}
			
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(queryResponseMsg)) == SUCCESS)
			{
				busy = TRUE;
			}
		}
	}

	void sendResBuf(uint8_t msgID, uint8_t destination, uint8_t ships[], uint8_t l)
	{
		uint8_t i=0;
		if(!busy)
		{
			uint8_t* qRMsg = (uint8_t*)(call Packet.getPayload(&pkt, l+4));
			if (qRMsg == NULL)
			{
				return ;
			}

			qRMsg[0] = msgID;
			qRMsg[1] = SYSTEM_ID;
			qRMsg[2] = destination;
			qRMsg[3] = l;

			for(i=0;i<l;i++)qRMsg[4+i]=ships[i];

			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, l+4) == SUCCESS)
			{
				busy = TRUE;
			}
		}	
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
		if(len == sizeof(queryMsg))
		{
			queryMsg* resMsg = (queryMsg*)payload;

			if(recQ_index < MAX_SC_RQL)
			{
				receiveQueue[recQ_index].request = resMsg->messageID;
				receiveQueue[recQ_index].senderID = resMsg->senderID;
				receiveQueue[recQ_index].sID = resMsg->shipID;
				recQ_index++;
				post sendResponse();
			}
			else post sendResponse(); //this message is dropped without notification
		}
		else ; //unknown message

		return msg;
	}
}
