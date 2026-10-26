
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
1002c51d4: d10103ff    	sub	sp, sp, #0x40
1002c51d8: a9024ff4    	stp	x20, x19, [sp, #0x20]
1002c51dc: a9037bfd    	stp	x29, x30, [sp, #0x30]
1002c51e0: 9100c3fd    	add	x29, sp, #0x30
1002c51e4: aa0203f3    	mov	x19, x2
1002c51e8: aa0003f4    	mov	x20, x0
1002c51ec: aa0203e0    	mov	x0, x2
1002c51f0: 94c6a2a0    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
1002c51f4: aa1403e0    	mov	x0, x20
1002c51f8: 94c69f44    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
1002c51fc: aa0003f4    	mov	x20, x0
1002c5200: 910003e8    	mov	x8, sp
1002c5204: aa1303e0    	mov	x0, x19
1002c5208: 94c68f0b    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
1002c520c: aa1303e0    	mov	x0, x19
1002c5210: 94c6a292    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
1002c5214: 97ffff96    	bl	0x1002c506c <__text+0x2c1f34>
1002c5218: aa1403e0    	mov	x0, x20
1002c521c: 94c69f38    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
1002c5220: 910003e0    	mov	x0, sp
1002c5224: 97f537f5    	bl	0x1000131f8 <__text+0x100c0>
1002c5228: a9437bfd    	ldp	x29, x30, [sp, #0x30]
1002c522c: a9424ff4    	ldp	x20, x19, [sp, #0x20]
1002c5230: 910103ff    	add	sp, sp, #0x40
1002c5234: d65f03c0    	ret
