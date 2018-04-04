interface BufferOp<val_t>
{	
	//do something; now==TRUE do immediately, done when returned, now==FALSE do split-fase, when done signal event done
	command error_t doIt(val_t* sbuf, uint16_t count, bool now);
	//do something, write result to rbuf, leave dbuf untouched
	command error_t doItClean(val_t* dbuf, val_t* rbuf, uint16_t count, bool now);
	//done
	event void done(val_t* dbuf, val_t* rbuf, error_t err);
	
	
}