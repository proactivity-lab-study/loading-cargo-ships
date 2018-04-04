#include "comm.h"
#include "game_types.h"

module CraneCommunicationP
{
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
	provides interface CraneLink;
}
implementation 
{
	/************************************************************
	 *	Send messages
	 ************************************************************/
	message_t pkt;
	bool busy = FALSE;

	command error_t CraneLink.newPosition(uint8_t xloc, uint8_t yloc, bool cargoPlaced)
	{
		if (!busy)
		{
			craneLocationMsg* cmdMsg = (craneLocationMsg*)(call Packet.getPayload(&pkt, sizeof(craneLocationMsg)));
			if (cmdMsg == NULL)
			{
				return FAIL;
			}
			cmdMsg->messageID = CRANE_LOCATION_MSG;
			cmdMsg->senderID = CRANE_ID;
			cmdMsg->x_coordinate = xloc;
			cmdMsg->y_coordinate = yloc;
			cmdMsg->cargoPlaced = cargoPlaced;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(craneLocationMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
			return FAIL;
		}
		return EBUSY;
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
		if (len == sizeof(craneCommandMsg))
		{
			craneCommandMsg* locMsg = (craneCommandMsg*)payload;
			if(locMsg->messageID == CRANE_COMMAND_MSG)
			{
				signal CraneLink.newCommand(locMsg->senderID, locMsg->cmd);
			}
		}
		else ;
		return msg;
	}

	default event void CraneLink.newCommand(uint8_t senderID, uint8_t cmd){}
}