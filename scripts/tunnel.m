(* kernel init file which allows for tunneling MathLink connections to a remote Mathematica kernel through SSH. *)
(* See https://github.com/sakra/Tunnel/blob/master/MANUAL.md for usage hints. *)
(* Copyright 2015-2016 Sascha Kratky, see accompanying license file. *)

BeginPackage["MathLink`Tunnel`"]

SetupTunnelKernelConfiguration::usage = "SetupTunnelKernelConfiguration creates a tunneled controller kernel configuration."
SetupTunnelKernelConfiguration::missing = "Required tunnel launch script `1` does not exist."
SetupTunnelKernelConfiguration::name = "Invalid configuration name \"`1`\"."

RemoteMachineTunnel::usage = "RemoteMachineTunnel creates a compute kernel RemoteMachine description using a tunneled connection."
RemoteMachineTunnel::missing = "Required tunnel launch script `1` does not exist."

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

KernelVersionStr[versionNumber_] := ToString[NumberForm[versionNumber, {3,1}]]

VersionedKernelPath[system_String, versionNumber_] :=
	Which[
		system === "MacOSX" && versionNumber >= 10.0,
			"/Applications/Mathematica " <> KernelVersionStr[versionNumber] <> ".app/Contents/MacOS/WolframKernel",
		system === "MacOSX",
			"/Applications/Mathematica " <> KernelVersionStr[versionNumber] <> ".app/Contents/MacOS/MathKernel",
		system === "Windows" && versionNumber >= 10.0,
			"C:\\Program Files\\Wolfram Research\\Mathematica\\" <> KernelVersionStr[versionNumber] <> "\\WolframKernel.exe",
		system === "Windows",
			"C:\\Program Files\\Wolfram Research\\Mathematica\\" <> KernelVersionStr[versionNumber] <> "\\MathKernel.exe",
		versionNumber >= 10.0,
			"/usr/local/Wolfram/Mathematica/" <> KernelVersionStr[versionNumber] <> "/Executables/WolframKernel",
		True, (* default to Unix conventions *)
			"/usr/local/Wolfram/Mathematica/" <> KernelVersionStr[versionNumber] <> "/Executables/MathKernel"
	]

DefaultKernelPath[system_String, versionNumber_] :=
	Which[
		system === "MacOSX" && versionNumber >= 10.0,
			"/Applications/Mathematica.app/Contents/MacOS/WolframKernel",
		system === "MacOSX",
			"/Applications/Mathematica.app/Contents/MacOS/MathKernel",
		system === "Windows" && versionNumber >= 10.0,
			"WolframKernel.exe",
		system === "Windows",
			"MathKernel.exe",
		versionNumber >= 10.0,
			"/usr/local/bin/WolframKernel",
		True, (* default to Unix conventions *)
			"/usr/local/bin/MathKernel"
	]

SetupTunnelKernelConfiguration[name_String, remoteMachine_String, OptionsPattern[]] := Module[
	{configName,operatingSystem,versionNumber,evaluatorNames,tunnelScriptPath,kernelPath,config,configPos},
	If[$FrontEnd === Null, Message[FrontEndObject::notavail]; Return[$Failed]];
	configName = StringTrim[name];
	If[configName === "", Message[SetupTunnelKernelConfiguration::name, configName]; Return[$Failed]];
	operatingSystem = OptionValue["OperatingSystem"] /. { Automatic -> SystemInformation["FrontEnd", "OperatingSystem"] };
	versionNumber = OptionValue["VersionNumber"] /. { Automatic -> SystemInformation["FrontEnd", "VersionNumber"] };
	tunnelScriptPath = If[ SystemInformation["FrontEnd","OperatingSystem"] === "Windows",
		"`userbaseDirectory`\\FrontEnd\\tunnel.bat",
		"`userbaseDirectory`/FrontEnd/tunnel.sh"];
	kernelPath = OptionValue["KernelPath"] /. {
		Automatic -> VersionedKernelPath[operatingSystem, versionNumber],
		Default -> DefaultKernelPath[operatingSystem, versionNumber]
	};
	(* check for installed tunnel script only if front end is using a local kernel *)
	If [ SystemInformation["FrontEnd", "MachineID"] === SystemInformation["Kernel", "MachineID"],
		StringReplace[tunnelScriptPath, "`userbaseDirectory`" -> $UserBaseDirectory] //
		If[ Not@FileExistsQ[#], Message[SetupTunnelKernelConfiguration::missing, #] ]&
	];
	config = {
		"RemoteMachine"->True,
		"TranslateReturns"->True,
		"AppendNameToCellLabel"->True,
		"AutoStartOnLaunch"->False,
		"MLOpenArguments"->"-LinkMode Listen -LinkProtocol TCPIP -LinkOptions MLDontInteract -LinkHost 127.0.0.1",
		"LoginScript"->"\"" <> tunnelScriptPath <> "\" \"" <> remoteMachine <> "\" \"" <> kernelPath <> "\" \"`linkname`\""
	};
	evaluatorNames = EvaluatorNames /. Options[$FrontEnd] /. {EvaluatorNames -> {"Local" -> {"AutoStartOnLaunch" -> True}}};
	configPos = Position[evaluatorNames, Rule[configName, _]];
	(* upsert config in list of EvaluatorNames *)
	evaluatorNames = If[configPos==={},
		Print["New configuration \"" <> configName <> "\" added to kernel configuration options."];
		Append[evaluatorNames, Rule[configName, config]],
	(*Else*)
		Print["Existing configuration \"" <> configName <> "\" updated in kernel configuration options."];
		ReplacePart[evaluatorNames, First[configPos]->Rule[configName, config]]
	];
	(* persist updated list of EvaluatorNames *)
	SetOptions[$FrontEnd, EvaluatorNames->evaluatorNames];
	Rule[configName, config]
]
Options[SetupTunnelKernelConfiguration] = {"OperatingSystem"->Automatic, "VersionNumber"->Automatic, "KernelPath"->Automatic}

RemoteMachineTunnel[remoteMachine_String, kernelCount_Integer:1, OptionsPattern[]] := Module[
	{operatingSystem,versionNumber,kernelPath,host,tunnelScriptPath,loginScript},
	operatingSystem = OptionValue["OperatingSystem"] /. { Automatic -> $OperatingSystem };
	versionNumber = OptionValue["VersionNumber"] /. { Automatic -> $VersionNumber };
	kernelPath = OptionValue["KernelPath"] /. {
		Automatic -> VersionedKernelPath[operatingSystem, versionNumber],
		Default -> DefaultKernelPath[operatingSystem, versionNumber]
	};
	host = Last@StringSplit[remoteMachine, "@"];
	tunnelScriptPath = FileNameJoin[{
		$UserBaseDirectory, "FrontEnd",
		If[ $OperatingSystem === "Windows", "tunnel_sub.bat", "tunnel_sub.sh" ]
	}];
	If[ Not@FileExistsQ[tunnelScriptPath], Message[RemoteMachineTunnel::missing, tunnelScriptPath] ];
	loginScript = "\"" <> tunnelScriptPath <> "\" \"" <> remoteMachine <> "\" \"" <> kernelPath <> "\" \"`2`\"";
	(* Windows needs a set of extra quotes around command to make processing with cmd.exe /C work *)
	If[ $OperatingSystem === "Windows", loginScript = "\"" <> loginScript <> "\""];
	SubKernels`RemoteKernels`RemoteMachine[ host, loginScript, kernelCount, LinkHost->"127.0.0.1", System`KernelSpeed->OptionValue["KernelSpeed"] ]
]
Options[RemoteMachineTunnel] = {"OperatingSystem"->Automatic, "VersionNumber"->Automatic, "KernelPath"->Automatic, "KernelSpeed" -> 1}

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
