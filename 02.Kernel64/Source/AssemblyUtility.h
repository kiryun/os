#ifndef __ASSEMBLYUTILITY_H
#define __ASSEMBLYUTILITY_H

#include "Types.h"

// 함수
BYTE kInPortByte(WORD wPort);
void kOutPortByte(WORD wPort, BYTE bData);

#endif