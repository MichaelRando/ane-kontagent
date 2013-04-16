package com.jesusla.kontagent;

import java.util.HashMap;
import java.util.Map;
import android.content.Context;
import com.jesusla.ane.Extension;
import com.kontagent.Kontagent;
import android.os.AsyncTask; 
import android.content.SharedPreferences;

public class KontagentPollInstallReceiver extends AsyncTask<Void, Void, Void> {
	
	protected Void doInBackground(Void... v) {
		// Only on first run
		if (!Kontagent.isFirstRun()) {
			Extension.debug("Kontagent.isFirstRun returns false");
			return null;
		}
		Extension.debug("Kontagent.isFirstRun returns true");

	  
		Map<String, String> apaParams = new HashMap<String, String>();
		// su is a unique tracking tag required to match installs and ad
		// clicks. so the same value must be used in this call as well
		// as the applicaitonAdded call.
		apaParams.put("su", KontagentLib.getAndroidId());

		long time = System.currentTimeMillis();
		SharedPreferences p;
		try {
			while (System.currentTimeMillis() < time + 5000) {
				p = InstallTracker.getSharedPreferences();
				// check for updates on the referrer information every ~0.1 second for 5 seconds.
				if ( (p != null) && (p.getString("is_ucc", null) != null) ) {

					// send the UCC message with the referrer information required.
			    Map<String, String> uccParams = new HashMap<String, String>();

			    // su is a unique tracking tag required to match installs and ad
			    // clicks. so the same value must be used in this call as well
			    // as the applicaitonAdded call.
			    uccParams.put("su", KontagentLib.getAndroidId());

			    // parse parameters from InstallReceiver and put into uccParams
			    for (String type : new String[] { "st1", "st2", "st3" }) {
				    String value = p.getString(type, null);
				    if (value != null) {
					    uccParams.put(type, value);
				    }
			    }

				  if ((uccParams.get("st1") != null)) {
			  	  Kontagent.undirectedCommunicationClick(false, "ad", uccParams);
			    }
		      
		      break;
		    }  
		  }
		  Thread.sleep(100);
    }
    catch (InterruptedException e) {
	  	Extension.debug(e.toString());
	  }

	  // otherwise there was no referrer information, so we just send
	  // a regular install message
	  Kontagent.applicationAdded(apaParams);
	  return null;
	}
}