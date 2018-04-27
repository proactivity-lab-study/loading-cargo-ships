#include "comm.h"
#include "game_types.h"

module ShipCommunicationP
{
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
	uses interface Leds;
	provides interface ShipLink;
}
implementation 
{
	/************************************************************
	 *	Send messages
	 ************************************************************/
	message_t pkt;
	bool busy = FALSE;

	//for receive
	uint8_t tpsID, tptID, mpsID, mpcmd, rsID, ra;

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

	command error_t ShipLink.sendResponse(uint8_t shipID, bool approved)
	{
		if (!busy)
		{
			shipProposalResponse* prpMsg = (shipProposalResponse*)(call Packet.getPayload(&pkt, sizeof(shipProposalResponse)));
			if (prpMsg == NULL)
			{
				return FAIL;
			}
			prpMsg->messageID = SHIP_PROPOSAL_RESPONSE_MSG;
			prpMsg->senderID = TOS_NODE_ID;
			if(approved)prpMsg->approved = 1;
			else prpMsg->approved = 0;

			if(call AMSend.send(shipID, &pkt, sizeof(shipProposalResponse)) == SUCCESS)
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
	task void targetProp()
	{
		signal ShipLink.targetProposalFrom(tpsID, tptID);
	}

	task void moveProp()
	{
		signal ShipLink.moveProposalFrom(mpsID, mpcmd);
	}

	task void respMsg()
	{
		if(ra != 0)signal ShipLink.responseFrom(rsID, TRUE);
		else signal ShipLink.responseFrom(rsID, FALSE);
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		uint8_t msgID;
		//target propsal, move proposal and response messages are all 3 bytes long
		if (len == 3)
		{
			msgID = *(uint8_t*)payload;
			if(msgID == SHIP_TARGET_PROPOSAL_MSG)
			{
				shipTargetProposal* rmsg = (shipTargetProposal*)payload;

				//check again to be sure
				if(rmsg->messageID == SHIP_TARGET_PROPOSAL_MSG)
				{
					//signal ShipControlP but do it split-phase
					tpsID = rmsg->senderID;
					tptID = rmsg->targetID;
					post targetProp();
				}
			}
			else if(msgID == SHIP_MOVE_PROPOSAL_MSG)
			{
				shipMoveProposal* rmsg = (shipMoveProposal*)payload;

				//check again to be sure
				if(rmsg->messageID == SHIP_MOVE_PROPOSAL_MSG)
				{
					//signal ShipControlP
					mpsID = rmsg->senderID;
					mpcmd = rmsg->cmd;
					post moveProp();
				}
			}
			else if(msgID == SHIP_PROPOSAL_RESPONSE_MSG)
			{
				shipProposalResponse* rmsg = (shipProposalResponse*)payload;

				//check again to be sure
				if(rmsg->messageID == SHIP_PROPOSAL_RESPONSE_MSG)
				{
					//signal ShipControlP
					rsID = rmsg->senderID;
					ra = rmsg->approved;
					post respMsg();
				}
			}
			else ;//must be some other type of message with len == 3
		}
		else ;//must be some other type of message

		return msg;
	}

	default event void ShipLink.targetProposalFrom(uint8_t shipID, uint8_t targetID){}
	default event void ShipLink.moveProposalFrom(uint8_t shipID, uint8_t cmd){}
	default event void ShipLink.responseFrom(uint8_t shipID, bool approved){}
}