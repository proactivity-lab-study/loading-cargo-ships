#include "Serial.h"
//#include "./SpecialSerialP/HdlcTranslate2C.nc"
//#include "./SpecialSerialP/PlatformSerial2C.nc"
//#include "./SpecialSerialP/Serial2P.nc"


//#include "logger.h"
configuration FlushBufferToSerialC {
	provides interface BufferOp<float> as FlushFloat;
	provides interface BufferOp<uint8_t> as FlushUint8t;
	provides interface BufferOp<uint8_t> as FlushUint8t_2;//I'm just lazy
	provides interface BufferOp<uint16_t> as FlushUint16t;
	provides interface BufferOp<uint32_t> as FlushUint32t;
	provides interface SplitControl;
}
implementation {
	
	components FlushBufferToSerialP, MainC;
	
	components Serial2P, HdlcTranslate2C, PlatformSerial2C, LedsC;
	Serial2P.SerialFrameComm -> HdlcTranslate2C;
	Serial2P.SerialControl -> PlatformSerial2C;
	HdlcTranslate2C.UartStream -> PlatformSerial2C;
	MainC.SoftwareInit -> Serial2P.Init;
	SplitControl = Serial2P.SplitControl;
	
	FlushBufferToSerialP.SendBytePacket -> Serial2P;
	FlushBufferToSerialP.ReceiveBytePacket -> Serial2P;
	
	FlushFloat = FlushBufferToSerialP.FlushFloat;
	FlushUint8t = FlushBufferToSerialP.FlushUint8t;
	FlushUint8t_2 = FlushBufferToSerialP.FlushUint8t_2;
	FlushUint16t = FlushBufferToSerialP.FlushUint16t;
	FlushUint32t = FlushBufferToSerialP.FlushUint32t;
}
	
