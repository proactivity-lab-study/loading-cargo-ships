
#ifndef COMM_H
#define COMM_H


#define AM_CRANECOMMUNICATION 6
#define AM_SYSTEMCOMMUNICATION 7


/************************************************************
 *	Radio message structures
 ************************************************************/
//-------- SHIP MESSAGE STRUCTURES

typedef nx_struct shipTargetProposal {
	nx_uint8_t messageID;
	nx_uint8_t senderID;
	nx_uint8_t targetID;
} craneLocationMsg;

//propose next command to send to crane
typedef nx_struct shipMoveProposal {
	nx_uint8_t messageID;
	nx_uint8_t senderID;
	nx_uint8_t cmd;//command
} craneCommandMsg;

//propose next command to send to crane
typedef nx_struct shipProposalResponse {
	nx_uint8_t messageID;
	nx_uint8_t senderID;
	nx_uint8_t approved; //0 - not agreed, >1 - agreed
} craneCommandMsg;



//-------- CRANE MESSAGE STRUCTURES

typedef nx_struct craneLocationMsg {
	nx_uint8_t messageID;
	nx_uint8_t senderID;
	nx_uint8_t x_coordinate;
	nx_uint8_t y_coordinate;
	nx_uint8_t cargoPlaced;
} craneLocationMsg;

typedef nx_struct craneCommandMsg {
	nx_uint8_t messageID;
	nx_uint8_t senderID;
	nx_uint8_t cmd;//command
} craneCommandMsg;

//-------- SYSTEM MESSAGE STRUCTURES

typedef nx_struct queryMsg { //structure for all system queries and welcome message
	nx_uint8_t messageID; //this defines the type of the query 
	nx_uint8_t senderID;
	nx_uint8_t shipID; //optional, not used in all queries
} queryMsg;

typedef nx_struct queryResponseMsg { //structure for all system queries and welcome message responses
	nx_uint8_t messageID; //this defines the type of the response
	nx_uint8_t senderID;
	nx_uint8_t shipID; 
	nx_uint16_t departureT; //optional, not used in all responses
	nx_uint8_t x_coordinate; //optional, not used in all responses
	nx_uint8_t y_coordinate; //optional, not used in all responses
	nx_uint8_t isCargoLoaded;//optional, not used in all responses
} queryResponseMsg;

/************************************************************
 *	Serial message structures
 ************************************************************/

typedef nx_struct serialCraneLocMsg { //this struct is actually not used, length depends on how many winners there are
	nx_uint8_t length;
	nx_uint8_t messageID;
	nx_uint8_t xLoc;
	nx_uint8_t yLoc;
	nx_uint8_t isCargoPlaced;
	nx_uint8_t popularCmdWinner1;
	nx_uint8_t popularCmdWinner2;
	//nx_uint8_t popularCmdWinner3;
	//nx_uint8_t popularCmdWinner4;
} serialCraneLocMsg;

typedef nx_struct newShipSerialMsg {
	nx_uint8_t length;
	nx_uint8_t messageID;
	nx_uint8_t shipID;
	nx_uint8_t xLoc;
	nx_uint8_t yLoc;
	nx_uint16_t dTime;	
} newShipSerialMsg;

typedef nx_struct gTimeSerialMsg {
	nx_uint8_t length;
	nx_uint8_t messageID;
	nx_uint16_t gTime;	
} gTimeSerialMsg;


//not related to communication, but I don't want to make a new h-file
typedef struct locBundle {
	uint8_t x_coordinate;
	uint8_t y_coordinate;
}locBundle;


#endif // COMM_H