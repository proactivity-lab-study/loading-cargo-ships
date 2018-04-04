interface DatabaseLink
{
	command error_t update();
	event void updateDone(error_t err);
}