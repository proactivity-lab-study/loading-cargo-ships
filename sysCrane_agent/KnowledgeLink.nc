#include "comm.h"

interface KnowledgeLink
{
	command bool isCargoHere(uint8_t craneX, uint8_t craneY);
	command void cargoPlacedTo(uint8_t craneX, uint8_t craneY);
	command uint8_t getIndex(uint8_t senderID);
	command uint8_t getID(uint8_t index);

	event void getCraneLoc(uint8_t *x, uint8_t *y);
}
