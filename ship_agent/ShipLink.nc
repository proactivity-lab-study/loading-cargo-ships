interface ShipLink
{
	//NB! all events (targetProposalFrom, moveProposalFrom, responseFrom) are split-phase
	//i.e they are triggered from 'tasks'. You can call the command functions directly from
	//the event functions, no need to use additional split-phase'ing and tasks.


	//send stuff to other ships
	command error_t targetProposal(uint8_t target_id, uint8_t recepient_ship_id);
	command error_t moveProposal(uint8_t move, uint8_t recepient_ship_id);
	
	//receive stuff from other ships
	event void targetProposalFrom(uint8_t shipID, uint8_t targetID);
	event void moveProposalFrom(uint8_t shipID, uint8_t cmd);

	//send and receive responses to stuff
	command error_t sendResponse(uint8_t shipID, bool approved);
	event void responseFrom(uint8_t shipID, bool approved);

	

}