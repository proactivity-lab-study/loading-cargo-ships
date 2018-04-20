#include "comm.h"
#include "game_types.h"

module ShipCommunicationP
{
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
	provides interface ShipLink;
}
implementation 
{
	/************************************************************
	 *	Send messages
	 ************************************************************/
	message_t pkt;
	bool busy = FALSE;

	command error_t ShipLink.targetProposal(uint8_t target_id, uint8_t ship_id)
	{
		if (!busy)
		{
			shipTargetProposal* prpMsg = (shipTargetProposal*)(call Packet.getPayload(&pkt, sizeof(shipTargetProposal)));
			if (prpMsg == NULL)
			{
				return FAIL;
			}
			prpMsg->messageID = SHIP_TARGET_PROPOSAL_MSG;
			prpMsg->senderID = TOS_NODE_ID;
			prpMsg->targetID = target_id;
			if(call AMSend.send(ship_id, &pkt, sizeof(shipTargetProposal)) == SUCCESS)
			{
				busy = TRUE;
				return SUCCESS;
			}
			return FAIL;
		}
		else return EBUSY;
	}

	command error_t ShipLink.moveProposal(uint8_t move, uint8_t shipID)
	{
		if (!busy)
		{
			shipMoveProposal* prpMsg = (shipMoveProposal*)(call Packet.getPayload(&pkt, sizeof(shipMoveProposal)));
			if (prpMsg == NULL)
			{
				return FAIL;
			}
			prpMsg->messageID = SHIP_MOVE_PROPOSAL_MSG;
			prpMsg->senderID = TOS_NODE_ID;
			prpMsg->cmd = move;
			if(call AMSend.send(shipID, &pkt, sizeof(shipMoveProposal)) == SUCCESS)
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
		/*
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
		*/
	}

	//default event void CraneLink.craneLocation(uint8_t loc_x, uint8_t loc_y, uint8_t cPlaced){}
	//default event void CraneLink.craneCommandFrom(uint8_t sID, uint8_t c){}
}