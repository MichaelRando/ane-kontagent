package com.jesusla.kontagent;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Intent;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import java.util.Set;
import java.util.Iterator;
import com.jesusla.ane.Extension;
import java.net.URLDecoder;

public class InstallTracker extends BroadcastReceiver
{
  static private SharedPreferences sharedPreferences;
  public static final int MODE_MULTI_PROCESS = 0x00000004;

  public void onReceive(Context paramContext, Intent paramIntent)
  {
	  Extension.debug("Kontagent.onReceive got an intent");
    sharedPreferences = paramContext.getSharedPreferences("kontagent_mobile_aquisition", MODE_MULTI_PROCESS);

    String referrer = paramIntent.getStringExtra("referrer");
    Extension.debug("Kontagent.onReceive referrer is: %s", referrer);
	  if (referrer == null) {
      return;
    }

    String decodedReferrer = URLDecoder.decode(referrer);
    /*
     * Parse out various referrer data here.
    */
    
    Editor pE = sharedPreferences.edit();
    // Change this as you would see fit to decode whatever type of referrer
    // you are expecting. Here we expect only expecting com.tapjoy.something
    String[] parts = decodedReferrer.split("\\.");

    if (parts.length >= 2) {
      pE.putString("st1", parts[1]);
      Extension.debug("st1 = %s", parts[1]);
    }
    if (parts.length >= 3) {
      pE.putString("st2", parts[2]);
      Extension.debug("st2 = %s", parts[2]);
    }
    // st1/2/3 are what let you drill down on Kontagent’s Ad page to
    // understand more about your ad campaigns, here we are using this to
    // indicate which provider (st1) and what Ad it was (st2)
    
    // indicate that there is a ucc with is_ucc; to be used later
    pE.putString("is_ucc", "yes");
    pE.commit();
  }
  static public SharedPreferences getSharedPreferences() {
    return sharedPreferences;
  }
}