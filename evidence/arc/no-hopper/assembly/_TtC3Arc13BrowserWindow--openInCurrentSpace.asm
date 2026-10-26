
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
10014c4f0: d10183ff    	sub	sp, sp, #0x60
10014c4f4: a90357f6    	stp	x22, x21, [sp, #0x30]
10014c4f8: a9044ff4    	stp	x20, x19, [sp, #0x40]
10014c4fc: a9057bfd    	stp	x29, x30, [sp, #0x50]
10014c500: 910143fd    	add	x29, sp, #0x50
10014c504: aa0203f3    	mov	x19, x2
10014c508: aa0003f4    	mov	x20, x0
10014c50c: aa0203e0    	mov	x0, x2
10014c510: 94cc85d8    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
10014c514: aa1403e0    	mov	x0, x20
10014c518: 94cc827c    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
10014c51c: aa0003f5    	mov	x21, x0
10014c520: 910043e8    	add	x8, sp, #0x10
10014c524: aa1303e0    	mov	x0, x19
10014c528: 94cc7243    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
10014c52c: aa1303e0    	mov	x0, x19
10014c530: 94cc85ca    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
10014c534: 900210c8    	adrp	x8, 0x104364000 <_xmlXPathRegisterNs+0x104364000>
10014c538: f9438108    	ldr	x8, [x8, #0x700]
10014c53c: f8686ab4    	ldr	x20, [x21, x8]
10014c540: 52800fa8    	mov	w8, #0x7d               ; =125
10014c544: f90003e8    	str	x8, [sp]
10014c548: 52800028    	mov	w8, #0x1                ; =1
10014c54c: 390023e8    	strb	w8, [sp, #0x8]
10014c550: 910003e0    	mov	x0, sp
10014c554: 941a98c1    	bl	0x1007f2858 <__text+0x7ef720>
10014c558: 94cc8566    	bl	0x10346daf0 <_xmlXPathRegisterNs+0x10346daf0>
10014c55c: 910043e0    	add	x0, sp, #0x10
10014c560: 97fb1b26    	bl	0x1000131f8 <__text+0x100c0>
10014c564: aa1503e0    	mov	x0, x21
10014c568: 94cc8265    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
10014c56c: a9457bfd    	ldp	x29, x30, [sp, #0x50]
10014c570: a9444ff4    	ldp	x20, x19, [sp, #0x40]
10014c574: a94357f6    	ldp	x22, x21, [sp, #0x30]
10014c578: 910183ff    	add	sp, sp, #0x60
10014c57c: d65f03c0    	ret
