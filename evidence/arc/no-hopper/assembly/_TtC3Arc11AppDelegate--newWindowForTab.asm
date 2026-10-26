
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
100231fc0: d10103ff    	sub	sp, sp, #0x40
100231fc4: a9024ff4    	stp	x20, x19, [sp, #0x20]
100231fc8: a9037bfd    	stp	x29, x30, [sp, #0x30]
100231fcc: 9100c3fd    	add	x29, sp, #0x30
100231fd0: aa0003f4    	mov	x20, x0
100231fd4: b4000162    	cbz	x2, 0x100232000 <__text+0x22eec8>
100231fd8: aa0203f3    	mov	x19, x2
100231fdc: aa1403e0    	mov	x0, x20
100231fe0: 94c8ebca    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100231fe4: aa1303e0    	mov	x0, x19
100231fe8: 94c8ef22    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
100231fec: 910003e8    	mov	x8, sp
100231ff0: 94c8db91    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
100231ff4: aa1303e0    	mov	x0, x19
100231ff8: 94c8ef18    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
100231ffc: 14000005    	b	0x100232010 <__text+0x22eed8>
100232000: 6f00e400    	movi.2d	v0, #0000000000000000
100232004: ad0003e0    	stp	q0, q0, [sp]
100232008: aa1403e0    	mov	x0, x20
10023200c: 94c8ebbf    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100232010: 97fffeb9    	bl	0x100231af4 <__text+0x22e9bc>
100232014: aa1403e0    	mov	x0, x20
100232018: 94c8ebb9    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
10023201c: b0020961    	adrp	x1, 0x10435f000 <_xmlXPathRegisterNs+0x10435f000>
100232020: 913a2021    	add	x1, x1, #0xe88
100232024: 900194a2    	adrp	x2, 0x1034c6000 <_xmlXPathRegisterNs+0x1034c6000>
100232028: 9129c042    	add	x2, x2, #0xa70
10023202c: 910003e0    	mov	x0, sp
100232030: 97f754e5    	bl	0x1000073c4 <__text+0x428c>
100232034: a9437bfd    	ldp	x29, x30, [sp, #0x30]
100232038: a9424ff4    	ldp	x20, x19, [sp, #0x20]
10023203c: 910103ff    	add	sp, sp, #0x40
100232040: d65f03c0    	ret
