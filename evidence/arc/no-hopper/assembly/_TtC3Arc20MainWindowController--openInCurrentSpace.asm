
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
1003207b0: d10103ff    	sub	sp, sp, #0x40
1003207b4: a9024ff4    	stp	x20, x19, [sp, #0x20]
1003207b8: a9037bfd    	stp	x29, x30, [sp, #0x30]
1003207bc: 9100c3fd    	add	x29, sp, #0x30
1003207c0: b4000122    	cbz	x2, 0x1003207e4 <__text+0x31d6ac>
1003207c4: aa0203f3    	mov	x19, x2
1003207c8: aa0203e0    	mov	x0, x2
1003207cc: 94c53529    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
1003207d0: 910003e8    	mov	x8, sp
1003207d4: 94c52198    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
1003207d8: aa1303e0    	mov	x0, x19
1003207dc: 94c5351f    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
1003207e0: 14000003    	b	0x1003207ec <__text+0x31d6b4>
1003207e4: 6f00e400    	movi.2d	v0, #0000000000000000
1003207e8: ad0003e0    	stp	q0, q0, [sp]
1003207ec: f00201e1    	adrp	x1, 0x10435f000 <_xmlXPathRegisterNs+0x10435f000>
1003207f0: 913a2021    	add	x1, x1, #0xe88
1003207f4: d0018d22    	adrp	x2, 0x1034c6000 <_xmlXPathRegisterNs+0x1034c6000>
1003207f8: 9129c042    	add	x2, x2, #0xa70
1003207fc: 910003e0    	mov	x0, sp
100320800: 97f39af1    	bl	0x1000073c4 <__text+0x428c>
100320804: a9437bfd    	ldp	x29, x30, [sp, #0x30]
100320808: a9424ff4    	ldp	x20, x19, [sp, #0x20]
10032080c: 910103ff    	add	sp, sp, #0x40
100320810: d65f03c0    	ret
