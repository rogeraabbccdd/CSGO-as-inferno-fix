//////////////////////////////////////////////////////////////////////////////////
// gamemode_vip.nut
//  Base script to handle all VIP gamemode related
//  logic & gameplay direction.
// 
//updates
//	- removed hacks for mp_maxrounds for previously borked game logic entities
//	- fixed gameplay objective monitoring not occuring when warmup match is skipped
//
if( GetDeveloperLevel() > 0 ) 
	printl( "Initializing gamemode_vip.nut" );

//const GAME_MAX_ROUNDS = 30;	//ensure this is equally divisable by 2
//const GAME_CAN_CLINCH = 1;  //hardcoded value to replace mp_match_can_clinch until game entities are fixed

//////////////////////////////////////////////////////////////////////////////////
// GLOBAL VARS

m_bGameStarted 		<- false;	// warm-up finished?
m_bRoundActive		<- false;	// round is currently in session?
m_bLastRoundHalf 	<- false;	// trigger when on the last round of the first half
m_bHalfTimeHit 		<- false;	// at half-time yet?
m_bEndGameHit		<- false;	// game finished?
m_bOnInitialFreeze 	<- false;	// in freeze mode on first round of first half
m_bIsWarmup 		<- false;	// is game currently in warmup?
m_bRoundWinTriggered <- false;	// true if the latest round end was triggered internally by the script
m_bVIPKilled		 <- false;	// flag signalling that the VIP has been killed

m_iRoundNumber 		<- 0;		// current round that is being played, 0=warmup
m_iRoundsPlayed 	<- 0;		// number of rounds completed
//m_iRoundsLeft		<- GAME_MAX_ROUNDS; // hack: annoying way of fixing the broken round logic.
					   // both the game_round_end & 'FireWinConditions'of map param entities
					   // don't decrement rounds like they should... so we do it here 
					   // tediously and probably buggy.

m_iNumCTs			<- 0;		// current total CT players, updated at the start of each round
m_iNumTs			<- 0;		// current total T players, updated at the start of each round
m_iNumCTWins		<- 0;		// for manual score-tracking. reset only on map load
m_iNumTWins			<- 0;		// ^ ditto
//m_bIsEliminationRound		<- false;	// flag to trigger a special hack, yay.
//m_bResetRoundsOnHalf  <- false;		// yet another hack flag
//m_iNumRoundsRegistered <-0;		// this is the 'official' (ie broken) number of rounds the game code
								// 'thinks' we have played. keep track to hack-in a proper half-time
m_bSwitchTeams	<- false;		// flag signalling a team switch at halftime

m_flCheckVIPWeapons <- Time();	// think time for checking VIP weapon restrictions
m_bCheckVIPWeapons  <- false;	// used to trigger an immediate check of VIP weapons
m_flCheckBuyzoneThink <- Time();// think timer for the vip buyzone proximity algorithm
m_flBuyzoneRenableThink <- Time();// think timer for the vip buyzone proximity algorithm
m_bBuyTimeExpired	<- false;		// buytime expired (used to disable buyzone proximity checks)
						// a list of buyzones dsiabled by vip being in proximity. does a later check
						// to ensure vip is outside of range before re-enabling to avoid timing/flicker issues
m_DisabledBuyzones <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
                       null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null ];

m_pCurrentVIP		<- null;	// ent reference to VIP player
m_pPreviousVIPs		<- [null,null,null,null,null,null,null,null,null,null];	// list of previous 10 VIPs

								// player entity lists for both teams. upto 32 players each, 64 max	
const MAX_PLAYERS_PER_TEAM	= 32;	//redundant							
m_PlayerListCTs <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
m_PlayerListTs  <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
				   		 
				   				   
VIP_PLAYER_MODEL	<- "models/player/custom_player/legacy/ctm_sas_variante.mdl"
CT_PLAYER_MODELS	<- 
{
   model_0 = "models/player/custom_player/legacy/ctm_sas.mdl",
   model_1 = "models/player/custom_player/legacy/ctm_sas_varianta.mdl",
   model_2 = "models/player/custom_player/legacy/ctm_sas_variantb.mdl",
   model_3 = "models/player/custom_player/legacy/ctm_sas_variantc.mdl",
   model_4 = "models/player/custom_player/legacy/ctm_sas_variante.mdl",	// make sure this matches VIP_PLAYER_MODEL & is always last	
}
T_PLAYER_MODELS	<- 
{
   model_0 = "models/player/custom_player/legacy/tm_separatist.mdl",
   model_1 = "models/player/custom_player/legacy/tm_separatist_varianta.mdl",
   model_2 = "models/player/custom_player/legacy/tm_separatist_variantb.mdl",
   model_3 = "models/player/custom_player/legacy/tm_separatist_variantc.mdl",
   model_4 = "models/player/custom_player/legacy/tm_separatist_variantd.mdl",
}	
		   
enum GLOBAL_STATUS_MSG
{
	VIP_NOT_ESCAPED,
	VIP_ESCAPED,
	VIP_KILLED,	
}
		
// this is basically a list of every weapon in the game, minus knife, nades and pistols
VIP_WEAPON_RESTRICTIONS	<- 
{
	wpn_0 = "weapon_ak47",		//primary	
	wpn_1 = "weapon_m4a1",					
	wpn_2 = "weapon_galilar",				
	wpn_3 = "weapon_famas",   				
	wpn_4 = "weapon_aug",					
	wpn_5 = "weapon_sg556",					
	wpn_6 = "weapon_ssg08",					
	wpn_7 = "weapon_awp",					
	wpn_8 = "weapon_scar20",				
	wpn_9 = "weapon_g3sg1",					
	wpn_10 = "weapon_bizon",					
	wpn_11 = "weapon_m249",					
	wpn_12 = "weapon_mac10",				
	wpn_13 = "weapon_mag7",				
	wpn_14 = "weapon_mp9",				
	wpn_15 = "weapon_negev",				
	wpn_16 = "weapon_nova",					
	wpn_17 = "weapon_p90",					
	wpn_18 = "weapon_sawedoff",				
	wpn_19 = "weapon_ump45",					
	wpn_20 = "weapon_xm1014",				
	wpn_21 = "weapon_mp7",				
	wpn_22 = "weapon_mp5sd",				
}
		

function Precache()
{	
    foreach( m, model in CT_PLAYER_MODELS )
		{
			self.PrecacheModel(model);
		}
		foreach( m, model in T_PLAYER_MODELS )
		{
			self.PrecacheModel(model);
		}
}


//////////////////////////////////////////////////////////////////////////////////
// THINK
function Gamemode_VIP_Think()
{
//	printl( "gamemode_vip.nut | Gamemode_VIP_Think()" );

	// freeze state: at end of warm-up and before match started
	if( m_bOnInitialFreeze )
	{
		if( GetDeveloperLevel() > 0 )
			printl( "gamemode_vip.nut | Gamemode_VIP_Think() PREMATCH FREEZE!" );

		m_bIsWarmup = false;
		
	
		return;
	}
	else if( m_bEndGameHit )
	{
		if( GetDeveloperLevel() > 0 )
			printl( "gamemode_vip.nut | Gamemode_VIP_Think() END GAME THINK!" );
		return;
	}
	else if( !m_bRoundActive )
	{
		// half-time, before very start of next round (w/ freeze time)
		if( m_bHalfTimeHit )
		{
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | Gamemode_VIP_Think() HALF-TIME THINK!" );
				
				//hack hack
//			if( !m_bResetRoundsOnHalf )
//			{			
//				EntFire( "@ServerCommand", "Command", "mp_maxrounds " + m_iRoundsLeft, 5 );//reset rounds after changing it to trigger halftime
//				m_bResetRoundsOnHalf = true;
//				m_bIsEliminationRound = true;//hack: enable elimination round after halftime triggered
				
				//swap around our internal team score tally for after the team switch
//				local temp = m_iNumCTWins;
//				m_iNumCTWins = m_iNumTWins;
//				m_iNumTWins = temp;
//			}

		}
		else if( m_iRoundNumber > 0 )
		{
			// note: on the last round of the first half, triggering this will be skipped and set to 'half-time think' immediately
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | Gamemode_VIP_Think() EndRoundThink! @ ROUND " + m_iRoundNumber );	
		}
		
		return;
	}
	else if( m_iRoundNumber < 1 )
	{
		//trigger this once, just incase it needs reset
		if( !m_bIsWarmup )
			EntFire( "@ServerCommand", "Command", "mp_humanteam any" , 0 );	// re-allow CT/VIP team-switching
		
		if( GetDeveloperLevel() > 0 )
			printl( "gamemode_vip.nut | Gamemode_VIP_Think() WARM-UP THINK!" );
			
		m_bIsWarmup = true;
		return;
	}
	
	// ------------ BEGIN --------------
	// after all conditions have passed, function starts here for the 'active' monitoring stage
	//	printl( "gamemode_vip.nut | Gamemode_VIP_Think() ACTIVE! @ ROUND " + m_iRoundNumber + " VIP Hp=" + m_pCurrentVIP.GetHealth() );	

	//only do these wasteful calculations during buytime. shorten the default buytime to improve performance if necessary
	if( !m_bBuyTimeExpired  )
	{
		CheckDisabledBuyzones();
		DisableBuyzonesInProximity();
	}
	
	try
	{	
		//keep this here as dummy code. try to access m_pCurrentVIP to trigger an exception if null
		if( m_pCurrentVIP.GetHealth() ) // removed hack: !m_bIsEliminationRound 
		{}
					
		if( m_bVIPKilled )	
			OnVIPKilled();		
		else if( (Time() > m_flCheckVIPWeapons) || m_bCheckVIPWeapons )
		{
			CheckVIPWeapons(); 
			m_flCheckVIPWeapons = Time() + 10;	// once every 10 seconds/6x a minute (gets triggered immediately on a CT item pickup event)
		}		
	}
	//when the try throws an exception it means that the VIP pointer went null: player disconnect usually
	//in that case signal a draw and restart the round
	catch( any )
	{
		printl( "gamemode_vip.nut | Gamemode_VIP_Think()! | VIP WENT MISSING!" );
		
		if( !m_bRoundActive )
			return;
		
		m_bRoundActive = false;	
		m_pCurrentVIP = null;
		
		BuildPlayerLists();
		SelectRandomVIP();
		
		SendStartSignalCT();		// obviously send these last, as they depend on the player lists & VIP
		SendStartSignalT();			
		SendStartSignalVIP();
		
		EntFire( "@RoundEndVIP", "EndRound_Draw", 5.0, 0.01 );
	}	
}



//////////////////////////////////////////////////////////////////////////////////
// HELPERS & LOGIC

//
// reset to defaults
function ResetGamemode()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | ResetGamemode()" );
	
	m_bGameStarted 		<- false;	
	m_bRoundActive		<- false;	
	m_bLastRoundHalf 	<- false;	
	m_bHalfTimeHit 		<- false;	
	m_bEndGameHit		<- false;
	m_bOnInitialFreeze 	<- false;
	m_bIsWarmup 		<- false;
	m_bRoundWinTriggered <- false;
	m_bVIPKilled		<- false;
	m_iRoundNumber 		<- 0;		
	m_iRoundsPlayed 	<- 0;	
//	m_iRoundsLeft		<- GAME_MAX_ROUNDS;
	m_iNumCTs			<- 0;		
	m_iNumTs			<- 0;	
	m_iNumCTWins		<- 0;	
	m_iNumTWins			<- 0;
//	m_bIsEliminationRound		<- false;
//	m_bResetRoundsOnHalf  <- false;
//	m_iNumRoundsRegistered <-0;
	m_bSwitchTeams	  <- false;
	m_pCurrentVIP		<- null;
	m_pPreviousVIPs		<- [null,null,null,null,null,null,null,null,null,null];	
	
	m_flCheckVIPWeapons <- Time();	
	m_bCheckVIPWeapons  <- false;
	
	m_flCheckBuyzoneThink <- Time();
	m_flBuyzoneRenableThink <- Time();
	m_bBuyTimeExpired	<- false;						
	m_DisabledBuyzones <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
                       null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null ];
	
	m_PlayerListCTs <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
	m_PlayerListTs  <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
				   
	
}

//
// build the global player team lists
function BuildPlayerLists()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | BuildPlayerList()" );
	
	// reset player lists
	m_PlayerListCTs <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
	m_PlayerListTs  <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
				   null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];

	m_bVIPKilled <- false;
	
	m_iNumCTs	<- 0;		
	m_iNumTs	<- 0;

	player <- null;
	while (player = Entities.FindByClassname(player, "player") )
	{
		team <- player.GetTeam();
		printl( "BuildPlayerLists team: " + team );
		// T
		if(team == 2)
		{
			m_PlayerListTs[m_iNumTs] = player;
			m_iNumTs++;
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | BuildPlayerList() | FOUND PLAYER-TERR!" );
		}
		// CT
		else if( team == 3)
		{
			m_PlayerListCTs[m_iNumCTs] = player;
						
			m_iNumCTs++;
			
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | BuildPlayerList() | FOUND PLAYER-CT! entindex="+player.entindex() );
		}
	}
}

// checks a potential VIP against a list of upto 10 previous VIPs scaled
// with the total number of CTs, returns true if player is an eligable VIP
function CheckIfEligableVIP( player )
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | CheckIfEligableVIP()" );
	
	index <- 0;	
	while( (index < 10) && (index < (m_iNumCTs-1)) )
	{
		if( player == m_pPreviousVIPs[index] )
		{
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | CheckIfEligableVIP()  -- REJECTED" );
			return false;
		}
			
		index++;
	}
	
	return true;
}

// randomly selects a CT from list to be VIP, also keeps a list of the last 10 players to be VIP
// to ensure they don't get selected again (for at least 10 rounds, pending on player availability)
function SelectRandomVIP()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | SelectRandomVIP()" );
	
	//todo: maybe doesn't need this?
	if( m_pCurrentVIP != null )
		return;
	
	//todo: test and fix as required
	if( m_iNumCTs < 1 || m_iNumTs < 1 )
	{
		printl( "NOT ENOUGH PLAYERS TO BEGIN VIP MATCH... RESTARTING.");
		ResetGamemode();
		EntFire( "@ServerCommand", "Command", "mp_restartgame 30" , 0 );// restart game in 30 seconds
		return;
	}
	
	// go through and make sure nobody else is using the VIP model
	player <- null;
	while( (player = Entities.FindByModel( player, VIP_PLAYER_MODEL )) != null )
	{
		if( player.GetClassname() == "player" )
		{
			// set to a random CT model that's not the VIP		
			player.SetModel( CT_PLAYER_MODELS["model_"+RandomInt(0,3)] );			
		}
	}
	
//	if( m_bIsEliminationRound || m_bIsWarmup )//hack hack-disable vip selection on elimination round
//	{
//		m_pCurrentVIP = null;
//		return;
//	}
	
	found_vip <- false;
	
	while( !found_vip )
	{
		rand_int <- RandomInt( 0, m_iNumCTs - 1 );
		
		if( (m_PlayerListCTs[rand_int] != null) && (CheckIfEligableVIP( m_PlayerListCTs[rand_int] )==true) )
		{
			if( GetDeveloperLevel() > 0 )
				printl( "gamemode_vip.nut | FOUND A VIP!" );	
			
			m_pCurrentVIP = m_PlayerListCTs[rand_int];			
			m_pCurrentVIP.SetModel( VIP_PLAYER_MODEL );
			m_pCurrentVIP.SetMaxHealth( 150 );
			m_pCurrentVIP.SetHealth( 150 );	
			
			// remove any previous weapons
			// for human players this will drop their primary weapon and strip everything else.
			// the strip is sent after a slight delay. bots will not drop weapons but will be stripped.
			CheckVIPWeapons();
						
			EntFire( "@WeaponStripVIP", "Strip", "", 0.2, m_pCurrentVIP );		
			
			//trigger spawning of vip equip template in 1/2 a second
			EntFire( "@VIPSpawnEquip", "Trigger", "", 0.50, m_pCurrentVIP );	
			
			spawn <- Entities.FindByName( null, "@SpawnVIP" );
			
			if( spawn == null )
			{
				printl( "gamemode_vip.nut | SelectRandomVIP() | ERROR: VIP spawn entity not setup correctly. Please make a disabled \'info_player_counterterrorist\' and name it \"@SpawnVIP\"" );
			}
			else
			{			
				// move to VIP spawn position
				m_pCurrentVIP.SetOrigin( spawn.GetOrigin() );
			}		
			
			found_vip <- true;
		}			
	}		
	
}

// sends a gameplay status msg via a hudhint to all players on a team
//
function SendGlobalStatusMsg( msg )
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | SendGlobalStatusMsg()" );

	player <- null;
	while (player = Entities.FindByClassname(player, "player") )
	{
		team <- player.GetTeam();
		// Not spec
		if(team != 1)
		{
			switch( msg )
			{
				case GLOBAL_STATUS_MSG.VIP_NOT_ESCAPED:
					EntFire( "@StatusMsg_VIPNotEscaped", "ShowHudHint", 3.5, 0, player );
					break;
				case GLOBAL_STATUS_MSG.VIP_ESCAPED:
					EntFire( "@StatusMsg_VIPEscaped", "ShowHudHint", 3.5, 0, player );
					break;
				case GLOBAL_STATUS_MSG.VIP_KILLED:
					EntFire( "@StatusMsg_VIPKilled", "ShowHudHint", 3.5, 0, player );
					break;
			}	
		}
	}
}

// function to fix the borked functionality of 'game_round_end' not counting rounds or triggering half-time, etc
// check for game state and trigger the proper command manually and restore the score afterwards
// returns true if game is clinched
//function CheckGameState()
//{
	//manually check for the game clinch
//	if( GAME_CAN_CLINCH )
//	{
		//check for clinched		
//		if( m_iNumCTWins >= (GAME_MAX_ROUNDS/2) )
//		{
			// CTs win, end the game		
//			EntFire( "@ServerCommand", "Command", "mp_maxrounds "+m_iNumRoundsRegistered, 0 );// trick the game into triggering endgame
//			m_bEndGameHit = true;
//			return;
//		}	
//		else if( m_iNumTWins >= (GAME_MAX_ROUNDS/2) )
//		{
			// Ts win, end the game		
//			EntFire( "@ServerCommand", "Command", "mp_maxrounds "+m_iNumRoundsRegistered, 0 );// trick the game into triggering endgame
//			m_bEndGameHit = true;
//			return true;
//		}
//	}

	//check for match point
//	if( m_iNumCTWins == ((GAME_MAX_ROUNDS/2)-1) || m_iNumCTWins == ((GAME_MAX_ROUNDS/2)-1) )
//	{
//		local rounds = m_iNumRoundsRegistered + 1;
//		EntFire( "@ServerCommand", "Command", "mp_maxrounds "+rounds, 0 );// trick the game into triggering 'last round' alert
//	}
//	else
	// check if we've reached last round before half-time
//	if( m_bLastRoundHalf && ((m_iNumCTWins + m_iNumTWins) == ((GAME_MAX_ROUNDS/2)-2)) )	// use -2 because we want it set on the round before the last round of half
//	{
		//printl( "LAST ROUND OF HALF! XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" );
	
		//m_bLastRoundHalf = true;	
		
		// hack here: we've determined that we're actually at halftime despite the game logic
		// saying otherwise. use the number of rounds the game knows about, double it and minus one and set
		// maxrounds to that to trigger 'last match of half' in the game code
//		local halftime_hack = (m_iNumRoundsRegistered*2);
		
//		if( halftime_hack < 2 )
//			halftime_hack = 2;
 
//		EntFire( "@ServerCommand", "Command", "mp_maxrounds " + halftime_hack, 0 );// trick the game into triggering 'last round of half' alert & halftime
//		m_bIsEliminationRound = true;
//		//m_iRoundsLeft = (GAME_MAX_ROUNDS/2)-1;	// set this just in case
//	}
	
//	return false;
//}


// cycle through CTs by player models and check their current health,
// returns number of CTs still alive (including the VIP)
function CheckNumCTsAlive()
{
	num_cts_alive <- 0;
	
	// iterate through CTs
	player <- null;
	while (player = Entities.FindByClassname(player, "player") )
	{
		team <- player.GetTeam();
		if(team == 3 && player.GetHealth() > 0)
		{
			num_cts_alive++;
		}
	}
	return num_cts_alive;
}

// cycle through Ts by player models and check their current health,
// returns number of Ts still alive 
function CheckNumTsAlive()
{
	num_ts_alive <- 0;
	
	// iterate through Ts
	player <- null;
	while (player = Entities.FindByClassname(player, "player") )
	{
		team <- player.GetTeam();
		if(team == 2 && player.GetHealth() > 0)
		{
			num_ts_alive++;
		}
	}
	
	return num_ts_alive;
}

// cycle through all the weapons in the game, checking to search if any of them have an 'owner' that
// matches the maxhealth of the VIP. if so, remove weapon from the VIP
function CheckVIPWeapons()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | CheckVIPWeapons()" );

		
	// iterate through weapons
	foreach( wpn, wpnstr in VIP_WEAPON_RESTRICTIONS )
	{
		weapon <- null;
		while( (weapon = Entities.FindByClassname( weapon, wpnstr )) != null )
		{
			if( (weapon.GetOwner() != null) && ((weapon.GetOwner()).GetMaxHealth() == 150) )
			{
				if( GetDeveloperLevel() > 0 )
					printl( "gamemode_vip.nut | CheckVIPWeapons() | VIP HAS RESTRICTED WEAPON ="+wpnstr);
				
				EntFire( "@ClientCommand", "Command", "slot1" , 0.00, m_pCurrentVIP );	// select primary slot
				EntFire( "@ClientCommand", "Command", "drop" , 0.05, m_pCurrentVIP );	// drop				
			}
		}		
	}
	
	m_bCheckVIPWeapons = false;
}


// give the VIP a personal cash bonus
// also takes care of removing weapons and teleporting vip to safety (kind of an odd place here)
function GiveVIPCashBonus()
{
	//hack:ensure at least 1 round is won by the game's built-in win conditions.... so we can further hack it into doing what we want
	//disable objectives on first round of game & first round after half-time (to be fair)
	//UPDATE: removed hack: m_bIsEliminationRound 
	if( m_bIsWarmup )	
		return;	

	if( m_pCurrentVIP == null )
	{
		//currentvip may have been reset, if null check if previous vip list still has a reference
		if( m_pPreviousVIPs[0] != null )
		{
			// give the VIP a bonus for touching the escape zone
			EntFire( "@RoundCashBonusVIP", "AddMoneyPlayer", 0, 0, m_pPreviousVIPs[0] );	
			SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_ESCAPED );
			
			m_pPreviousVIPs[0].SetHealth( 0 );
			m_pPreviousVIPs[0].SetMaxHealth( 0 );
			// remove any weapons
			EntFire( "@WeaponStripVIP", "Strip", "", 0, m_pPreviousVIPs[0] );	
			
			// this is done with a trigger-teleport now:
			// NM. reenabled. the trigger_teleport entity, yet another one, is broken. 'default disabled' doesn't work
			spawn <- Entities.FindByName( null, "@SpawnVIP_SafeArea" );
				
			if( spawn != null )
			{
				// move to VIP safe spawn position
				m_pPreviousVIPs[0].SetOrigin( spawn.GetOrigin() );
			}	
			
		}
	
	}
	else
	{		
		// give the VIP a bonus for touching the escape zone
		EntFire( "@RoundCashBonusVIP", "AddMoneyPlayer", 0, 0, m_pCurrentVIP );	
		SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_ESCAPED );
		
		m_pCurrentVIP.SetHealth( 0 );
		m_pCurrentVIP.SetMaxHealth( 0 );
		// remove any weapons
		EntFire( "@WeaponStripVIP", "Strip", "", 0, m_pCurrentVIP );
		
		// this is done with a trigger-teleport now:
		// NM. reenabled. the trigger_teleport entity, yet another one, is broken. 'default disabled' doesn't seem to work
		spawn <- Entities.FindByName( null, "@SpawnVIP_SafeArea" );
			
		if( spawn != null )
		{
			// move to VIP safe spawn position
			m_pCurrentVIP.SetOrigin( spawn.GetOrigin() );
		}
	}
}

//
//
function DisableBuyzonesInProximity()
{
	if( m_pCurrentVIP == null )
		return;
		
	if( Time() < m_flCheckBuyzoneThink )
		return;
		
	m_flCheckBuyzoneThink = Time() + 0.25;	//4x a second

			
	//limit zones in proximity
	zone2 <- null;
	while( (zone2  = Entities.FindByClassnameWithin( zone2, "func_buyzone", m_pCurrentVIP.GetOrigin(), 96 )) != null )
	{
		if( zone2.GetTeam() != 2 )//only CT or 'nobody' buyzones 
		{
			EntFire( zone2.GetName(), "SetTeam_None", "", 0 );			
			AddBuyzoneToDisabledList( zone2.GetName() );			
		}
	}	
	
}

//
//
function AddBuyzoneToDisabledList( name )
{
	if( name == null )
		return;
		
	for( local i=0; i<32; i+=1 )
	{
		// found an empty slot or a one with a matching name
		if( m_DisabledBuyzones[i] == null || m_DisabledBuyzones[i] == name )
		{
		//	if( m_DisabledBuyzones[i] == null )
		//		printl("Disabling new CT Buyzone: "+name);
				
			m_DisabledBuyzones[i] = name;
			return;
		}
	}
}

//
//
function CheckDisabledBuyzones()
{
	if( m_DisabledBuyzones[0] == null )
		return;
	
	if( Time() < m_flBuyzoneRenableThink )
		return;
	
	m_flBuyzoneRenableThink <- Time() + 0.25;
		
	for( local i=0; i<32; i+=1 )
	{
		if( m_DisabledBuyzones[i] == null )
			return;
			
		buyzone <- Entities.FindByNameWithin( null, m_DisabledBuyzones[i], m_pCurrentVIP.GetOrigin(), 96 );
		
		// not in range, so re-enable
		if( buyzone == null )
		{
		//	printl("Reenabling CT Buyzone: "+m_DisabledBuyzones[i]);
			EntFire( m_DisabledBuyzones[i], "SetTeam_CTOnly", "", 0 );
			
			//remove from list and bump-up the rest
			for( local j=i; j<32; j+=1 )
			{
				// special case for the last one
				if( j < 31 )					
					m_DisabledBuyzones[j] = m_DisabledBuyzones[j+1]; 
				else
					m_DisabledBuyzones[j] = null;
			}
			
		}
	}
}


//////////////////////////////////////////////////////////////////////////////////
// INPUTS

//OnRoundAnnounceMatchStart()
// called on game event 'round_announce_match_start'
// gets called once per game:  when the freeze
// time on the first round runs-down (unless server restarts game or messes up)
function OnRoundAnnounceMatchStart()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnRoundAnnounceMatchStart()" );
	
	// case when match begins with not enough players, or not enough when the players list was
	// built. recheck if there's more players, and either retry after 30 seconds of waiting,
	// or jump into the match if there are enough players now
	if( (m_iNumCTs < 1 || m_iNumTs < 1) )
	{
		BuildPlayerLists();
		
		if( (m_iNumCTs < 1 || m_iNumTs < 1) )
		{
			ShowMessage( "NOTE ENOUGH PLAYERS TO BEGIN... RESTARTING");	// this doesn't actually seem to display anywhere?
			ResetGamemode();
			EntFire( "@ServerCommand", "Command", "mp_restartgame 30" , 0 );// restart game in 30 seconds
			return;
		}
		else// if( !m_bOnInitialFreeze )
		{	
	//		m_bIsEliminationRound = true; // hack: make first round an elimination round
			SelectRandomVIP();
		
			SendStartSignalCT();		// obviously send these last, as they depend on the player lists & VIP
			SendStartSignalT();			
			SendStartSignalVIP();			
		}
	}
	
	//update: fix sync-error when warmup is skipped
	m_bIsWarmup = false;
	
	m_iRoundsPlayed = 0;
	m_iRoundNumber = 1;
//	m_bIsEliminationRound		= true;
	//m_iRoundsLeft = GAME_MAX_ROUNDS;
	 
	m_bGameStarted = true;
	m_bOnInitialFreeze = false;	
	m_bRoundWinTriggered = false;
	m_bCheckVIPWeapons  <- false;
	m_flCheckBuyzoneThink <- Time();
	m_flBuyzoneRenableThink <- Time();
	m_bBuyTimeExpired	<- false;						
	m_DisabledBuyzones <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
                       null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null ];
}

//OnRoundAnnounceLastRoundHalf()
// called on game event 'round_announce_last_round_half'
// gets called once per game: when the freeze time runs
// down on the last round of the half. signals a reset next round.
function OnRoundAnnounceLastRoundHalf()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnRoundAnnounceLastRoundHalf()" );
	
	m_bLastRoundHalf = true;
	//m_bIsEliminationRound = true; //hack: make last round elimiation only to force halftime to be triggered. sigh
}


//OnCTPickedUpItem()
// called whenever a CT picks up an item
function OnCTPickedUpItem()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnCTPickedUpItem()" );	
		
	m_bCheckVIPWeapons = true;
}

//OnMultiNewRound()
// called at the very start of each round by logic_auto
function OnMultiNewRound()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnMultiNewRound()" );
	
	// do this here, because OnRoundStart isn't reliable during warmup-match
	// only triggers at start of match
	if( m_bIsWarmup )
	{
		m_bIsWarmup = false;
		m_bOnInitialFreeze = true;	
		m_bRoundWinTriggered = false;
		BuildPlayerLists();
			
	//	m_bIsEliminationRound = true; // hack: make first round an elimination round	
			
		SelectRandomVIP();
		
		SendStartSignalCT();		// obviously send these last, as they depend on the player lists & VIP
		SendStartSignalT();			
		SendStartSignalVIP();
		
		m_flCheckBuyzoneThink <- Time();
		m_flBuyzoneRenableThink <- Time();
		m_bBuyTimeExpired	<- false;						
		m_DisabledBuyzones <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
                       null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null ];
		
		EntFire( "@ServerCommand", "Command", "mp_humanteam CT" , 0 );	// disable VIP/CTs from switching teams during a round... mostly to prevent VIP from disappearing
		
	}
}

//OnRoundStart()
// called each time a new round starts, fired right at start before
// freeze time has expired. note this gets fired before
// OnRoundAnnounceMatchStart()
function OnRoundStart()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnRoundStart()" );
	
	//triggered every round except the first round
	if( m_bGameStarted )
	{
		m_iRoundNumber++;
		BuildPlayerLists();
		
		SelectRandomVIP();
		
		SendStartSignalCT();		// send these last, they depend on the player lists & VIP
		SendStartSignalT();			
		SendStartSignalVIP();
				
		EntFire( "@ServerCommand", "Command", "mp_humanteam CT" , 0 );	// disable VIP/CTs from switching teams during a round... mostly to prevent VIP from disappearing
	}
	
	// trigger at round start only after half-time
	if( m_bHalfTimeHit )
	{
		m_bGameStarted = true;
		m_bHalfTimeHit = false;
		BuildPlayerLists();
		SelectRandomVIP();
		
		SendStartSignalCT();		// send these last, they depend on the player lists & VIP
		SendStartSignalT();			
		SendStartSignalVIP();
		
		EntFire( "@ServerCommand", "Command", "mp_humanteam CT" , 0 );	// disable VIP/CTs from switching teams during a round... mostly to prevent VIP from disappearing
		
		
	}	
	
	m_bRoundWinTriggered = false;
	m_bRoundActive = true;		
	m_flCheckBuyzoneThink <- Time();
	m_flBuyzoneRenableThink <- Time();
	m_bBuyTimeExpired	<- false;						
	m_DisabledBuyzones <- [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
                       null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null ];
}

//OnRoundEnd()
// called each time right when a round ends
function OnRoundEnd()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnRoundEnd()" );
	
	// special case when the very first round ends before the freeze-timer runs up
	// logic will miss the 'announce_match_start' event, so this is required to set vars manually.
	if( !m_bGameStarted && m_bOnInitialFreeze )
	{
		m_bGameStarted = true;
		m_bOnInitialFreeze = false;
		m_iRoundNumber++;
		m_iRoundsPlayed++;
	}	
	
	if( m_bGameStarted )
	{
		m_iRoundsPlayed++;
				
		// in this case we need to do some extra checks to determine what it was that caused the round to end
		// and trigger the proper message is needed
		if( !m_bRoundWinTriggered )
		{
			// if there's still both CTs & Ts alive, the timer ran-up
			if( CheckNumCTsAlive() > 0 && CheckNumTsAlive() > 0 )
			{
				// send win reason msg
				SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_NOT_ESCAPED );
				
				//slaughter VIP so they don't get to keep their armor
				EntFire( "@ClientCommand", "Command", "kill" , 1.0, m_pCurrentVIP );
				EntFire( "@ScoreVIPNeutral", "ApplyScore", 1 , 1.0, m_pCurrentVIP );	// add a kill to neutralize the -1 from suicide	

				m_iNumTWins += 1; //manually keep track of score inside script
//				m_iNumRoundsRegistered += 1;
			}
			// case where terrorist win by elimination: ie killed the VIP last, still send the VIP killed message
			else if( CheckNumCTsAlive() < 1 && CheckNumTsAlive() > 0 )
			{
				SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_KILLED );
				
				m_iNumTWins += 1; //manually keep track of score inside script
//				m_iNumRoundsRegistered += 1;
			}
			// case where CTs win by elimination, strip VIP for next round
			else if( CheckNumCTsAlive() > 0 && CheckNumTsAlive() < 1 )
			{
				// strip weapons after a small delay
				EntFire( "@WeaponStripVIP", "Strip", "", 6.5, m_pCurrentVIP );	
				m_iNumCTWins += 1; //manually keep track of score inside script
//				m_iNumRoundsRegistered += 1;
			}
			
			m_bRoundWinTriggered = false;	
			
			//m_bIsEliminationRound = true;
		}
		//obviously only gets set once per reset
		// hack for broken round-tracking. 
//		 if( m_bIsEliminationRound )
//		{
//			m_bIsEliminationRound = false;
			
//		}
		
		if( m_pCurrentVIP != null )
		{
			//push-back the previous VIPs list: FIFO
			m_pPreviousVIPs[9] = m_pPreviousVIPs[8];
			m_pPreviousVIPs[8] = m_pPreviousVIPs[7];
			m_pPreviousVIPs[7] = m_pPreviousVIPs[6];
			m_pPreviousVIPs[6] = m_pPreviousVIPs[5];
			m_pPreviousVIPs[5] = m_pPreviousVIPs[4];
			m_pPreviousVIPs[4] = m_pPreviousVIPs[3];
			m_pPreviousVIPs[3] = m_pPreviousVIPs[2];
			m_pPreviousVIPs[2] = m_pPreviousVIPs[1];
			m_pPreviousVIPs[1] = m_pPreviousVIPs[0];
			m_pPreviousVIPs[0] = m_pCurrentVIP;		// set the latest VIP at the start of the list
				
			//m_pCurrentVIP.SetModel( CT_PLAYER_MODELS["model_"+RandomInt(0,3)] );	//reset model...myabe wait to do this at the start of the next round? causes an unpleasant instant flicker 
																				//between player models at the end of the round. ->ensure current vip isn't set to null before then in that case, or just use previous vip[0].
			m_pCurrentVIP.SetMaxHealth( 100 );
						
			//m_pCurrentVIP.SetHealth(  ); 
			m_pCurrentVIP <- null;
		}
	}
	
//	if( !CheckGameState() ) //manually check for half-time and other game states
//	{
		//make sure CheckGameState() is called before this
//		if( m_bLastRoundHalf )
//		{
//			m_bGameStarted = false;
//			m_bLastRoundHalf = false;
//			m_bHalfTimeHit = true;
//			m_iRoundNumber++;
			
//			m_pPreviousVIPs		<- [null,null,null,null,null,null,null,null,null,null];	// reset previous VIPs list
			
//			if( m_pCurrentVIP != null )
//			{
				//m_pCurrentVIP.SetModel( CT_PLAYER_MODELS["model_"+RandomInt(0,3)] );	// todo: set this to a standard null model maybe?
//				m_pCurrentVIP <- null;
//			}
//		}
//	}
	
	m_bRoundActive = false;
	EntFire( "@ServerCommand", "Command", "mp_humanteam any" , 0 );	// re-allow CT/VIP team-switching
}

	

		
//OnLoadGame()
// called once at start-up
function OnLoadGame()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnLoadGame()" );
	
}
	
		
//OnGameEnd()
// called once at end of game -needs fixed in hammer, doesnt get sent correct
function OnGameEnd()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnGameEnd()" );
	
	m_bEndGameHit = true;
}

//OnVIPEscaped()
// called by a vip escape zone instance, signalling VIP is in an escape zone
function OnVIPEscaped()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnVIPEscaped()" );	
	
	if( !m_bRoundActive )
		return;			
					
	//hack:ensure at least 1 round is won by the game's built-in win conditions.... so we can further hack it into doing what we want
	//disable objectives on first round of game
	// UPDATE: removed hack: m_bIsEliminationRound
	if( m_bIsWarmup )	
		return;	
		
	// TODO TODO need a better check here to guarentee this is the 'actual' vip
	// seems to get triggered when any CT is touches zone after a bot-takeover (ie: every CT becomes the VIP)	
		
	m_bRoundActive = false;

	EntFire( "@RoundEndVIP", "EndRound_CounterTerroristsWin", 7.0, 0.01 );
	EntFire( "@RoundScoreVIP", "AddScoreCT", 0, 0.01 );	
	EntFire( "@RoundCashBonusVIPEscaped", "AddTeamMoneyCT", 0, 0 );
	
	
	EntFire( "@ScoreVIPNeutral", "ApplyScore", 3, 0, m_pCurrentVIP );	// give some points to the VIP

	// hack: a means of fixing the broken roundend entity not decrementing rounds
//	m_iRoundsLeft -= 1;	
//	EntFire( "@ServerCommand", "Command", "mp_maxrounds "+m_iRoundsLeft, 0 ); // set new maxrounds to decrease 'rounds left' 

	EntFire( "@ServerCommand", "Command", "mp_humanteam any" , 0 );	// re-allow CT/VIP team-switching
	
	//SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_ESCAPED );
	m_bRoundWinTriggered = true;
	
	m_iNumCTWins += 1; //manually keep track of score inside script
}

//OnVIPKilled()
// called internally by the active think function when VIP health is below 1hp
function OnVIPKilled()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnVIPKilled()" );	
	
	if( !m_bRoundActive )
		return;
		
	//hack:ensure at least 1 round is won by the game's built-in win conditions.... so we can further hack it into doing what we want
	//disable objectives on first round of game
	//UPDATE: removed hack: m_bIsEliminationRound ||
	if( m_bIsWarmup )	
		return;
		
	m_bRoundActive = false;
	
		
	// do a check to see if the VIP was the last player on the CTs alive,
	// dont give vipcash reward because the default team elimination bonus is given
	// which doubles the reward money given to Ts in the case the VIP is the last CT killed	
	if( CheckNumCTsAlive() > 0 )
	{		

		//EntFire( "@TriggerWin", "FireWinCondition", 3, 0.01 );
	
		EntFire( "@RoundEndVIP", "EndRound_TerroristsWin", 5.0, 0.01 );
		EntFire( "@RoundScoreVIP", "AddScoreTerrorist", 0, 0.01 );	
		EntFire( "@RoundCashBonusVIPKilled", "AddTeamMoneyTerrorist", 0 );		

		// hack: a means of fixing the broken roundend entity not decrementing rounds
//		m_iRoundsLeft -= 1;	
//		EntFire( "@ServerCommand", "Command", "mp_maxrounds "+m_iRoundsLeft, 0 ); // set new maxrounds to decrease 'rounds left' 

		m_iNumTWins += 1; //manually keep track of score inside script
		

	}
	
	
	SendGlobalStatusMsg( GLOBAL_STATUS_MSG.VIP_KILLED );
	m_bRoundWinTriggered = true;
	
	EntFire( "@ServerCommand", "Command", "mp_humanteam any" , 0 );	// re-allow CT/VIP team-switching
	
}

//OnPlayerDeathCT()
// called whenever a CT player dies
function OnPlayerDeathCT()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnPlayerDeathCT()" );	
		
		// TODO TODO need a better check here to guarentee this is the 'actual' vip
		// seems to get trigger when any CT is killed after a bot-takeover (ie: every CT becomes the VIP)
	//on a CT death event check to see if it was the VIP that died, if so set
	// the vipkilled flag
	if( m_pCurrentVIP && m_pCurrentVIP.GetHealth() < 1 ) 	
		m_bVIPKilled = true;

}

//OnBuytimeEnded()
// as name implies
function OnBuytimeEnded()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | OnBuytimeEnded()" );	
		
	m_bBuyTimeExpired <- true;
}





//////////////////////////////////////////////////////////////////////////////////
// OUTPUTS

//
// Send round-objective msg to CTs (but not VIP)
function SendStartSignalCT()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | SendStartSignalCT()" );
	
	EntFire( "@StartSoundCT", "PlaySound", 0 , 7.1 );
	
/*
	index <- 0;
	while( m_PlayerListCTs[index] != null )
	{  
		// filter out VIP, they get their own message
		if( (m_pCurrentVIP != null) && (m_PlayerListCTs[index] != m_pCurrentVIP) )
			EntFire( "@RoundStartSignalCT", "ShowMessage", 0 , 7.1, m_PlayerListCTs[index] );
			
		index++;
	}
*/	
}

//
// Send round-objective msg to Ts
function SendStartSignalT()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | SendStartSignalT()" );
		
/*
	index <- 0;
	while( m_PlayerListTs[index] != null )
	{
			EntFire( "@RoundStartSignalT", "ShowMessage", 0 , 7.1, m_PlayerListTs[index] );
			index++;
	}
*/
}

//
// Send round-objective hud-hint to the VIP
function SendStartSignalVIP()
{
	if( GetDeveloperLevel() > 0 )
		printl( "gamemode_vip.nut | SendStartSignalVIP()" );

	if( m_pCurrentVIP != null )
	{
		EntFire( "@RoundStartSignalVIP", "ShowHudHint", 8.0 , 1.5, m_pCurrentVIP );
	}

}


