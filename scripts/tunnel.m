(* kernel init file which allows for tunneling MathLink connections to a remote Mathematica kernel through SSH. *)
(* See https://github.com/sakra/Tunnel/blob/master/MANUAL.md for usage hints. *)
(* Copyright 2015 Sascha Kratky, see accompanying license file. *)

BeginPackage["MathLink`Tunnel`"]

Begin["`Private`"]

CreateFrontEndLinkHost[] := Module[
	{pos,linkName,linkNameComponents,linkHost,IP4AddressPattern,IP4AddrToInteger,candidates},
	If[ValueQ[$ParentLink] && Head[$ParentLink] === LinkObject,
		(* extract linkHost from parent link *)
		linkName = $ParentLink[[1]];
		linkNameComponents = StringSplit[ linkName , {"@", ","} ];
		(* if not a TCPIP linkname, default to automatic selection of LinkHost *)
		If [ Length[linkNameComponents] != 4, Return[Automatic]];
		linkHost = linkNameComponents[[2]],
	(*Else*)
		(* search for -linkhost option on command line *)
		pos=Position[ToLowerCase[$CommandLine], "-linkhost"];
		pos=If[Length[pos]==1,pos[[1]][[1]] +1,Length[$CommandLine] + 1];
		(* if no -linkhost option on command line, default to automatic selection of LinkHost *)
		If[pos>Length[$CommandLine],Return[Automatic]];
		linkHost=$CommandLine[[pos]]
	];
	(* if linkhost is the loopback interface, we are done *)
	If[linkHost=="127.0.0.1", Return[linkHost]];
	(* heuristic: search for best matching IP4 address in $MachineAddresses on the same subnet *)
	IP4AddressPattern = RegularExpression["\\d{1,3}(\\.\\d{1,3}){3,3}"];
	IP4AddrToInteger = FromDigits[ToExpression[StringSplit[#,"."]],256]&;
	candidates = BitXor[
		IP4AddrToInteger /@ Select[$MachineAddresses, StringMatchQ[#, IP4AddressPattern] &],
		IP4AddrToInteger @ linkHost]
		// Ordering[#, 1]&
		// Part[ $MachineAddresses,#]&;
	If[Length[candidates]>0,
		(* best candidate is first in list *)
		First[candidates],
	(*Else*)
		(* no candidate, default to Automatic selection of LinkHost *)
		Return[Automatic]
	]
]

CreateFrontEndLinkName[] := Module[
	{pos,linkName,linkNameComponents},
	If [ !ValueQ[MathLink`$PortNumber],
		If[ValueQ[$ParentLink] && Head[$ParentLink] === LinkObject,
			(* extract linkHost from parent link *)
			linkName = $ParentLink[[1]],
		(*Else*)
			(* search for -linkname option on command line *)
			pos = Position[ ToLowerCase[$CommandLine], "-linkname" ];
			pos = If[ Length[pos]==1,pos[[1]][[1]] +1, Length[$CommandLine] + 1];
			(* if no -linkname option on command line, default to automatic selection of LinkName *)
			If[ pos>Length[$CommandLine], Return[Automatic] ];
			linkName=$CommandLine[[pos]]
		];
		linkNameComponents = StringSplit[ linkName , {"@", ","} ];
		(* check if link has been created on loopback interface *)
		If [ Length[linkNameComponents] === 4 && linkNameComponents[[2]] === "127.0.0.1",
			(* initialize port number from main link name *)
			(* port numbers beyond the parsed one are assumed to be properly forwarded over SSH *)
			MathLink`$PortNumber = Max[
				ToExpression[linkNameComponents[[1]]],
				ToExpression[linkNameComponents[[3]]]
				],
		(*Else*)
			Return[Automatic]
		]
	];
	Return [ StringJoin[
		{ToString[++MathLink`$PortNumber], "@127.0.0.1,",
		ToString[++MathLink`$PortNumber], "@127.0.0.1"}]
	]
]

(* override built-in function MathLink`CreateFrontEndLink with tunneling aware one *)

Unprotect[MathLink`CreateFrontEndLink]

MathLink`CreateFrontEndLink[] := Module[ {linkName, link},
	linkName = CreateFrontEndLinkName[];
	link = If [ linkName === Automatic,
		LinkCreate[
			LinkMode->Listen,
			LinkProtocol->MathLink`CreateFrontEndLinkProtocol[],
			LinkHost->CreateFrontEndLinkHost[] ],
	(*Else*)
		LinkCreate[
			linkName,
			LinkMode->Listen,
			LinkProtocol->"TCPIP" ]
	];
	MathLink`LinkSetPrintFullSymbols[link, True];
	Return[link]
]

Protect[MathLink`CreateFrontEndLink]

End[]

EndPackage[]
