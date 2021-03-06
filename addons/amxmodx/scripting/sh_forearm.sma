#include <amxmod>
#include <amxmisc>
#include <Vexd_Utilities>
#include <superheromod>

// Forearm

// CVARS
// forearm_level
// forearm_radius      # distance of people affected
// forearm_cooldown    # of seconds before Forearm can Slap again
// forearm_SlapDam     # How much damage per slap
// forearm_SlapNum     # How many times does he slap
// forearm_MinEnemyHP  # at what hp will he stop slapping the enemy
// forearm_dropchance  # how likely will he force the enemys gun to drop 0=never 1=rare 2=sometimes 3=often 4=always

// Forearm! Slap your enemys
// Based on the suggestion by Chivas2973
// Credits to {HOJ} Batman for code borrowed from Hulk, and to Barman for his Amx Uber slap plugin which i used to base some code off of

// GLOBAL VARIABLES
#define TE_WORLDDECAL   116
#define TE_BLOODSPRITE    115

new gHeroName[]="Forearm"
new bool:g_hasForearmPower[SH_MAXSLOTS+1]
new spr_blood_drop
new spr_blood_spray
//----------------------------------------------------------------------------------------------
public plugin_init()
{
  // Plugin Info
  register_plugin("SUPERHERO Forearm","2.0","Prowler")

  // DO NOT EDIT THIS FILE TO CHANGE CVARS, USE THE SHCONFIG.CFG
  // forearm_radius     # distance of people affected
  // forearm_cooldown   # of seconds before Forearm can Restun
  // forearm_stuntime   # of seconds before Forearm Stuns Everybody
  register_cvar("forearm_level", "10" )
  register_cvar("forearm_radius", "200" )
  register_cvar("forearm_cooldown", "30" )
  register_cvar("forearm_SlapNum", "10" )
  register_cvar("forearm_SlapDam", "9" )
  register_cvar("forearm_MinEnemyHP", "50" )
  register_cvar("forearm_dropchance","1")

  // FIRE THE EVENT TO CREATE THIS SUPERHERO!
  debugMessage("Attempting to create Forearm Hero")
  shCreateHero(gHeroName, "Mighty Slap!", "Slap your enemies Several times, send them flying!", true, "forearm_level" )

  // REGISTER EVENTS THIS HERO WILL RESPOND TO! (AND SERVER COMMANDS)
  register_event("ResetHUD","newRound","b")

  // KEY DOWN
  register_srvcmd("forearm_kd", "forearm_kd")
  shRegKeyDown(gHeroName, "forearm_kd")

  // INIT
  register_srvcmd("forearm_init", "forearm_init")
  shRegHeroInit(gHeroName, "forearm_init")

}
//----------------------------------------------------------------------------------------------
public forearm_init()
{
  new temp[6]
  // First Argument is an id
  read_argv(1,temp,5)
  new id=str_to_num(temp)

  // 2nd Argument is 0 or 1 depending on whether the id has iron man powers
  read_argv(2,temp,5)
  new hasPowers=str_to_num(temp)

  g_hasForearmPower[id]=(hasPowers!=0)

}
//----------------------------------------------------------------------------------------------
public newRound(id)
{
  gPlayerUltimateUsed[id]=false
  return PLUGIN_HANDLED
}
//----------------------------------------------------------------------------------------------
public Drop_weapoN(id)
{
 if(random_num(1,4) <= get_cvar_num("forearm_dropchance")) {
    new wpn,clip,ammo
    new wpnname[31]
    wpn = get_user_weapon(id,clip,ammo)
    get_weaponname(wpn,wpnname,31)
    engclient_cmd(id,"drop",wpnname)
    }
 return PLUGIN_CONTINUE
}
//----------------------------------------------------------------------------------------------
public plugin_precache()
{
  spr_blood_drop = precache_model("sprites/blood.spr")
  spr_blood_spray = precache_model("sprites/bloodspray.spr")
}
//----------------------------------------------------------------------------------------------
public fx_blood(origin[3])
{
    message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
    write_byte(TE_BLOODSPRITE)
    write_coord(origin[0]+random_num(-20,20))
    write_coord(origin[1]+random_num(-20,20))
    write_coord(origin[2]+random_num(-20,20))
    write_short(spr_blood_spray)
    write_short(spr_blood_drop)
    write_byte(248) // color index
    write_byte(10) // size
    message_end()
}
//----------------------------------------------------------------------------------------------
public fx_blood_large(origin[3],num)
{
  // Blood decals
  static const blood_large[2] = {204,205}

  // Large splash
  for (new i = 0; i < num; i++) {
    message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord(origin[0]+random_num(-50,50))
    write_coord(origin[1]+random_num(-50,50))
    write_coord(origin[2]-36)
    write_byte(blood_large[random_num(0,1)]) // index
    message_end()
  }
}
//----------------------------------------------------------------------------------------------
public slap_player(id) {
    new slapdam=get_cvar_num("forearm_SlapDam")
    new minenemyhp=get_cvar_num("forearm_MinEnemyHP")
    if (get_user_health(id) > minenemyhp){
    user_slap(id,slapdam)
    } else {
   }
    return PLUGIN_CONTINUE
}
//----------------------------------------------------------------------------------------------
// RESPOND TO KEYDOWN
public forearm_kd()
{
  if ( !hasRoundStarted() ) return PLUGIN_HANDLED

  new temp[6]
  new velocity[3]
  // First Argument is an id with Forearm Powers!
  read_argv(1,temp,5)
  new id=str_to_num(temp)

  if ( !is_user_alive(id) ) return PLUGIN_HANDLED

  new Float:vector[3]
  Entvars_Get_Vector(id, EV_VEC_velocity, vector)
  FVecIVec(vector, velocity)

  if ( velocity[2] < -10 || velocity[2] > 10 ) {
    // Forearm should technically be standing still to do this...  (i.e. no jump or air)
    playSoundDenySelect(id)
    return PLUGIN_HANDLED
  }
  new forearmRadius=get_cvar_num("forearm_radius")
  new forearmCooldown=get_cvar_num("forearm_cooldown")
  new slapnum=get_cvar_num("forearm_SlapNum")

  debugMessage("FOREARM Power", id)
  // Let them know they already used their ultimate if they have
  if ( gPlayerUltimateUsed[id] )
  {
    playSoundDenySelect(id)
    return PLUGIN_HANDLED
  }

  if ( !is_user_alive(id) ) return PLUGIN_HANDLED

    // OK Power slap enemies closer than x distance
  set_hudmessage(0, 100, 200, 0.05, 0.65, 2, 0.02, 4.0, 0.01, 0.1, 2)
  new userOrigin[3]
  new victimOrigin[3]
  new distanceBetween
  get_user_origin(id,userOrigin)
  for ( new x=1; x<=SH_MAXSLOTS; x++)
  {
     if ( (is_user_alive(x) && get_user_team(id)!=get_user_team(x)) )
     {
       get_user_origin(x,victimOrigin)
       distanceBetween = get_distance(userOrigin, victimOrigin )
       if ( distanceBetween < forearmRadius )
       {
        ForeArmClip(id)
        ultimateTimer(id, forearmCooldown * 1.0)
        Drop_weapoN(x)
        set_task(0.1, "slap_player", x, "", 0, "a", slapnum)
        fx_blood(victimOrigin)
        fx_blood_large(victimOrigin,3)
        show_hudmessage(x, "You have been ForeArm slapped!")
        }
        else{
        }
    }
    }
  return PLUGIN_HANDLED
}
//----------------------------------------------------------------------------------------------
public ForeArmClip(id) {

        if ( get_user_noclip(id) == 0) return
        else {
        set_user_noclip(id,0)
        set_user_health(id, -1)
        set_user_frags(id, get_user_frags(id)-1)
      }
    }
//----------------------------------------------------------------------------------------------
