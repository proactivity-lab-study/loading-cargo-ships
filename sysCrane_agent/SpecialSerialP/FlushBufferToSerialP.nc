/**
 * Count value is 16bit at the moment. This means that for float and uin32_t buffers
 * the max buffer length is 16383 elements. This should not be a problem presently
 * but in the future with bigger ROM and RAM, who knows.
 */

module FlushBufferToSerialP{
	uses {
		interface ReceiveBytePacket;
    	interface SendBytePacket;
	}
	provides
	{
		interface BufferOp<float> as FlushFloat;
		interface BufferOp<uint8_t> as FlushUint8t;
		interface BufferOp<uint8_t> as FlushUint8t_2;
		interface BufferOp<uint16_t> as FlushUint16t;
		interface BufferOp<uint32_t> as FlushUint32t;
	}
}
implementation
{
	enum {
		BUSY_UINT8T = 1,
		BUSY_UINT8T_2,
		BUSY_UINT16T,
		BUSY_UINT32T,
		BUSY_FLOAT
	};
	
	uint8_t *bufp;
	uint16_t next, cnt;
	uint8_t busy = 0;
	task void startS();
	
	command error_t FlushFloat.doIt(float* sbuf, uint16_t count, bool now)
	{
		if(now)return FAIL;
		else
		{
			atomic if(!busy)
			{
				busy = BUSY_FLOAT;
				bufp = (uint8_t *)sbuf;
				cnt = 4*count;
				next = 0;
				return post startS();
			}
			return EBUSY;
		}
	}
	
	command error_t FlushUint16t.doIt(uint16_t* sbuf, uint16_t count, bool now)
	{
		if(now)return FAIL;
		else
		{
			atomic if(!busy)
			{
				busy = BUSY_UINT16T;
				bufp = (uint8_t *)sbuf;
				cnt = 2*count;
				next = 0;
				return post startS();
			}
			return EBUSY;
		}
	}
	
	command error_t FlushUint32t.doIt(uint32_t* sbuf, uint16_t count, bool now)
	{
		if(now)return FAIL;
		else
		{
			atomic if(!busy)
			{
				busy = BUSY_UINT32T;
				bufp = (uint8_t *)sbuf;
				cnt = 4*count;
				next = 0;
				return post startS();
			}
			return EBUSY;
		}
	}
	
	command error_t FlushUint8t.doIt(uint8_t* sbuf, uint16_t count, bool now)
	{
		if(now)return FAIL;
		else
		{
			atomic if(!busy)
			{
				busy = BUSY_UINT8T;
				bufp = (uint8_t *)sbuf;
				cnt = count;
				next = 0;
				return post startS();
			}
			return EBUSY;
		}
	}

	command error_t FlushUint8t_2.doIt(uint8_t* sbuf, uint16_t count, bool now)
	{
		if(now)return FAIL;
		else
		{
			atomic if(!busy)
			{
				busy = BUSY_UINT8T_2;
				bufp = (uint8_t *)sbuf;
				cnt = count;
				next = 0;
				return post startS();
			}
			return EBUSY;
		}
	}
	
	task void startS()
	{
		atomic call SendBytePacket.startSend(*(bufp + next++));
	}
	
	async event uint8_t SendBytePacket.nextByte()
	{
		if(next < cnt) return *(bufp + next++);
		else call SendBytePacket.completeSend();
		return -1;
	}
	
	void returnBuffer(error_t err)
	{
		switch(busy)
		{
			case BUSY_UINT8T:
			signal FlushUint8t.done((uint8_t*)bufp, NULL, err);
			break;

			case BUSY_UINT8T_2:
			signal FlushUint8t_2.done((uint8_t*)bufp, NULL, err);
			break;
			
			case BUSY_UINT16T:
			signal FlushUint16t.done((uint16_t*)bufp, NULL, err);
			break;
			
			case BUSY_UINT32T:
			signal FlushUint32t.done((uint32_t*)bufp, NULL, err);
			break;
			
			case BUSY_FLOAT:
			signal FlushFloat.done((float*)bufp, NULL, err);
			break;
			
			default:
			break;
		}
		busy = 0;
	}
	
	task void doneS()
	{
		returnBuffer(SUCCESS);
	}
	
	task void doneF()
	{
		returnBuffer(FAIL);
	}
	
	async event void SendBytePacket.sendCompleted(error_t error)
	{
		if(error == SUCCESS)post doneS();
		else post doneF();
	}
	
	//receive not implemented, all bytes dropped
	async event error_t ReceiveBytePacket.startPacket(){return SUCCESS;}
	async event void ReceiveBytePacket.byteReceived(uint8_t data){return;}
	async event void ReceiveBytePacket.endPacket(error_t result){return;}
	
	//unsupported BufferOp commands
	command error_t FlushFloat.doItClean(float* dbuf, float* rbuf, uint16_t count, bool now){return FAIL;}
	command error_t FlushUint8t.doItClean(uint8_t* dbuf, uint8_t* rbuf, uint16_t count, bool now){return FAIL;}
	command error_t FlushUint8t_2.doItClean(uint8_t* dbuf, uint8_t* rbuf, uint16_t count, bool now){return FAIL;}
	command error_t FlushUint16t.doItClean(uint16_t* dbuf, uint16_t* rbuf, uint16_t count, bool now){return FAIL;}
	command error_t FlushUint32t.doItClean(uint32_t* dbuf, uint32_t* rbuf, uint16_t count, bool now){return FAIL;}
	
	default event void FlushUint8t.done(uint8_t* dbuf, uint8_t* rbuf, error_t err){}
	default event void FlushUint8t_2.done(uint8_t* dbuf, uint8_t* rbuf, error_t err){}
	default event void FlushUint16t.done(uint16_t* dbuf, uint16_t* rbuf, error_t err){}
	default event void FlushUint32t.done(uint32_t* dbuf, uint32_t* rbuf, error_t err){}
	default event void FlushFloat.done(float* dbuf, float* rbuf, error_t err){}
}