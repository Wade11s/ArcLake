
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
100235b0c: a9bd57f6    	stp	x22, x21, [sp, #-0x30]!
100235b10: a9014ff4    	stp	x20, x19, [sp, #0x10]
100235b14: a9027bfd    	stp	x29, x30, [sp, #0x20]
100235b18: 910083fd    	add	x29, sp, #0x20
100235b1c: aa0003f3    	mov	x19, x0
100235b20: aa0203e0    	mov	x0, x2
100235b24: 94c8dcf9    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100235b28: aa0003f5    	mov	x21, x0
100235b2c: aa1303e0    	mov	x0, x19
100235b30: 94c8dcf6    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100235b34: aa0003f4    	mov	x20, x0
100235b38: 94002642    	bl	0x10023f440 <__text+0x23c308>
100235b3c: aa1503e0    	mov	x0, x21
100235b40: 94c8dcef    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
100235b44: aa1403e0    	mov	x0, x20
100235b48: a9427bfd    	ldp	x29, x30, [sp, #0x20]
100235b4c: a9414ff4    	ldp	x20, x19, [sp, #0x10]
100235b50: a8c357f6    	ldp	x22, x21, [sp], #0x30
100235b54: 14c8dcea    	b	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
