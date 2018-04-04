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

	command error_t CraneLink.send_command(uint8_t cmd)
	{
		if (!busy)
		{
			craneCommandMsg* cmdMsg = (craneCommandMsg*)(call Packet.getPayload(&pkt, sizeof(craneCommandMsg)));
			if (cmdMsg == NULL)
			{
				return FAIL;
			}
			cmdMsg->messageID = CRANE_COMMAND_MSG;
			cmdMsg->senderID = TOS_NODE_ID;
			cmdMsg->cmd = cmd;
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(craneCommandMsg)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
			return FAIL;
		}
		else return EBUSY;
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
		uint8_t location_x;
		uint8_t location_y;
		bool cargoPlaced = FALSE;
		uint8_t shipID;
		uint8_t cmd;
	
		if (len == sizeof(craneLocationMsg))
		{
			craneLocationMsg* locMsg = (craneLocationMsg*)payload;
			if(locMsg->messageID == CRANE_LOCATION_MSG && locMsg->senderID == CRANE_ID)
			{
				location_x = locMsg->x_coordinate;
				location_y = locMsg->y_coordinate;
				if(locMsg->cargoPlaced != 0)cargoPlaced = TRUE;

				signal CraneLink.craneLocation(location_x, location_y, cargoPlaced);
			}
		}
		else if (len == sizeof(craneCommandMsg))
		{
			craneCommandMsg* cmdMsg = (craneCommandMsg*)payload;
			if(cmdMsg->messageID == CRANE_COMMAND_MSG)
			{
				shipID = cmdMsg->senderID;
				cmd = cmdMsg->cmd;

				signal CraneLink.craneCommandFrom(shipID, cmd);
			}
		}
		else ;
		return msg;
	}

	default event void CraneLink.craneLocation(uint8_t loc_x, uint8_t loc_y, uint8_t cPlaced){}
	default event void CraneLink.craneCommandFrom(uint8_t sID, uint8_t c){}
}