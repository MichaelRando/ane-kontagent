package com.kontagent 
{
	import com.kontagent.libs.adobe.crypto.MD5;
	import com.kontagent.libs.adobe.crypto.Base64Encoder;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ErrorEvent;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLLoader;
	import flash.net.URLVariables;
	import flash.utils.flash_proxy;
	import com.kontagent.libs.KtValidator;
	
	public class KontagentApi 
	{	
		private var sdkVersion:String = "as01";

		private var baseHttps:String = "https://";
		private var baseHttp:String = "http://";

		private var baseApiUrl:String = "api.geo.kontagent.net/api/v1/";
		private var baseTestServerUrl:String = "test-server.kontagent.com/api/v1/";
		
		private var apiKey:String = "";
		
		private var useTestServer:Boolean = false;
		private var validateParams:Boolean = false;
		private var useHttps:Boolean = false;
		
		// this flag indicates whether a message has been sent yet
		private var hasSentMessage:Boolean = false;
		
		/*
		* Kontagent class constructor
		*
		* @constructor
		*
		* @param {String} apiKey The app's Kontagent API key
		* @param {Object} [optionalParams] An object containing paramName => value
		* @param {bool} [optionalParams.useTestServer] Whether to send messages to the Kontagent Test Server
		* @param {bool} [optionalParams.validateParams] Whether to validate the parameters passed into the tracking method
		* @param {bool} [optionalParams.useHttps] Whether to use https (as oppose to http)
		*/
		public function KontagentApi(apiKey:String, optionalParams:Object = null):void
		{
			this.apiKey = apiKey;
			
			if (optionalParams != null) {
				this.useTestServer = (optionalParams.useTestServer) ? optionalParams.useTestServer : false;
				this.validateParams = (optionalParams.validateParams) ? optionalParams.validateParams : false;
				this.useHttps = optionalParams.useHttps ? optionalParams.useHttps : false;
			}
			this.baseApiUrl = (this.useHttps ? this.baseHttps : this.baseHttp) + this.baseApiUrl;
			this.baseTestServerUrl = (this.useHttps ? this.baseHttps : this.baseHttp) + this.baseTestServerUrl;
			
		}

		private function base64Encode(data:String):String
		{
			var b64:Base64Encoder = new Base64Encoder();
			b64.encode(data);
			return b64.toString();
		}

		/*
		* Sends an HTTP request by creating an <img> tag given a URL.
		*
		* @param {String} url The request URL
		* @param {Object} params An object containing paramName => value (ex: 's'=>123456789)
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure
		*/
		private function sendHttpRequest(url:String, params:Object, successCallback:Function = null, errorCallback = null):void
		{
			var request:URLRequest = new URLRequest(url);
			var loader:URLLoader = new URLLoader();
			
			request.data = this.paramsToURLVariables(params);
			
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			
			// assign callback if present
			if (successCallback != null) {
				loader.addEventListener(Event.COMPLETE, successCallback);
			}

			if (errorCallback != null) {
				loader.addEventListener(ErrorEvent.ERROR, function() { errorCallback('Error sending http request')} );
				loader.addEventListener(IOErrorEvent.IO_ERROR, function() { errorCallback('IO Error sending http request')} );
			} else {
				// Swallow all errors to avoid crashing app
				loader.addEventListener(ErrorEvent.ERROR, function(){} );
				loader.addEventListener(IOErrorEvent.IO_ERROR, function(){} );
			}
			
			// send the request
			loader.load(request);
		}
		
		/*
		* Sends the API message by creaNumberting an <img> tag.
		*
		* @param {String} messageType The message type to send ('apa', 'ins', etc.)
		* @param {Object} params An object containing paramName => value (ex: 's'=>123456789)
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure
		*/
		private function sendMessage(messageType:String, params:Object, successCallback:Function = null, errorCallback:Function = null):void
		{
			// tag the version of the library on first message
			if (!this.hasSentMessage) {
				params.sdk = this.sdkVersion;
				this.hasSentMessage = true;
			}

			// validate all the parameters
			if (this.validateParams == true) {
				for (var key:String in params) {					
					if (KtValidator.validateParameter(messageType, key, String(params[key])) == false) {
						// if a parameter fails to validate, fire the appropriate callback
						errorCallback("Invalid value for parameter '" + key + "'");
						return;
					}
				}
				if (KtValidator.validateSubtypes(params) == false) {
					errorCallback("Invalid subtypes used");
					return;
				}
			}
			
			var url:String = "";
			
			if (this.useTestServer) {
				url = this.baseTestServerUrl + this.apiKey + "/" + messageType + "/";
			} else {
				url = this.baseApiUrl  + this.apiKey + "/" + messageType + "/";
			}
			
			this.sendHttpRequest(url, params, successCallback, errorCallback);
		}
		
		/*
		* Converts the params object to a URLVariables object
		*
		* @param {Object} params The params object containing paramName => value (ex: 's'=>123456789)
		*
		* @return {URLVariables} The URLVariable object
		*/
		private function paramsToURLVariables(params:Object):URLVariables
		{
			var urlVariables:URLVariables = new URLVariables();
			
			for(var key:String in params) {
				urlVariables[key] = String(params[key]);
			}
			
			return urlVariables;
		}
		
		/*
		* Returns the current unix timestamp
		*
		* @return {int} The current timestamp
		*/
		private function getTimestamp():int
		{
			return (new Date()).getTime();
		}
		
		/*
		* Generates a unique tracking tag
		*
		* @return {String} A unique tracking tag
		*/
		public function genUniqueTrackingTag():String
		{
			var tag:String = "" + this.getTimestamp() + Math.floor(Math.random()*10000);
			tag = MD5.hash(tag);
			return tag.substr(0, 16);
		}
		
		/*
		* Generates a short unique tracking tag
		*
		* @return {String} A short unique tracking tag
		*/
		public function genShortUniqueTrackingTag():String
		{
			return this.genUniqueTrackingTag().substr(0, 8);
		}	
		
		/*
		* Sends an Invite Sent message to Kontagent.
		*
		* @param {Number} userId The UID of the sending user
		* @param {String} recipientUserIds A comma-separated list of the recipient UIDs
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	InviteSent->InviteResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackInviteSent(userId:Number, recipientUserIds:String, uniqueTrackingTag:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				s: userId,
				r: recipientUserIds,
				u: uniqueTrackingTag
			};
			
			if (optionalParams) {
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("ins", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Invite Response message to Kontagent.
		*
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	InviteSent->InviteResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.recipientUserId] The UID of the responding user
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackInviteResponse(uniqueTrackingTag:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				i: 0,
				u: uniqueTrackingTag
			};
			
			if (optionalParams) {
				if (optionalParams.recipientUserId) { params.r = optionalParams.recipientUserId; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("inr", params, successCallback, errorCallback);
		}
				
		/*
		* Sends an Notification Email Sent message to Kontagent.
		*
		* @param {Number} userId The UID of the sending user
		* @param {String} recipientUserIds A comma-separated list of the recipient UIDs
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	NotificationEmailSent->NotificationEmailResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackNotificationEmailSent(userId:Number, recipientUserIds:String, uniqueTrackingTag:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				s: userId,
				r: recipientUserIds,
				u: uniqueTrackingTag
			};
			
			if (optionalParams) {
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("nes", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Notification Email Response message to Kontagent.
		*
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	NotificationEmailSent->NotificationEmailResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.recipientUserId] The UID of the responding user
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackNotificationEmailResponse(uniqueTrackingTag:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				'i': 0,
				'u': uniqueTrackingTag
			};
			
			if (optionalParams) {
				if (optionalParams.recipientUserId) { params.r = optionalParams.recipientUserId; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }	
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("nei", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Stream Post message to Kontagent.
		*
		* @param {Number} userId The UID of the sending user
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	NotificationEmailSent->NotificationEmailResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {String} type The Facebook channel type
		*	(feedpub, stream, feedstory, multifeedstory, dashboard_activity, or dashboard_globalnews).
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackStreamPost(userId:Number, uniqueTrackingTag:String, type:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				's': userId,
				'u': uniqueTrackingTag,
				'tu': type
			};
			
			if (optionalParams) {
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("pst", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Stream Post Response message to Kontagent.
		*
		* @param {String} uniqueTrackingTag 32-digit hex string used to match 
		*	NotificationEmailSent->NotificationEmailResponse->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {String} type The Facebook channel type
		*	(feedpub, stream, feedstory, multifeedstory, dashboard_activity, or dashboard_globalnews).
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.recipientUserId] The UID of the responding user
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackStreamPostResponse(uniqueTrackingTag:String, type:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				i: 0,
				u: uniqueTrackingTag,
				tu: type
			};
			
			if (optionalParams) {
				if (optionalParams.recipientUserId) { params.r = optionalParams.recipientUserId; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("psr", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Custom Event message to Kontagent.
		*
		* @param {Number} userId The UID of the user
		* @param {String} eventName The name of the event
		* @param {Object} [optionalParam] An associative array containing paramName => value
		* @param {int} [optionalParams.value] A value associated with the event
		* @param {int} [optionalParams.level] A level associated with the event (must be positive)
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackEvent(userId:Number, eventName:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				s: userId,
				n: eventName
			};
			
			if (optionalParams) {
				if (optionalParams.value) { params.v = optionalParams.value; }
				if (optionalParams.level != undefined) { params.l = optionalParams.level; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("evt", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Application Added message to Kontagent.
		*
		* @param {Number} userId The UID of the installing user
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.uniqueTrackingTag] 16-digit hex string used to match 
		*	Invite/StreamPost/NotificationSent/NotificationEmailSent->ApplicationAdded messages. 
		*	See the genUniqueTrackingTag() helper method.
		* @param {String} [optionalParams.shortUniqueTrackingTag] 8-digit hex string used to match 
		*	ThirdPartyCommClicks->ApplicationAdded messages. 
		*	See the genShortUniqueTrackingTag() helper method.
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackApplicationAdded(userId:Number, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void
		{
			var params:Object = {s: userId};

			if (optionalParams) {
				if (optionalParams.uniqueTrackingTag) { params.u = optionalParams.uniqueTrackingTag; }
				if (optionalParams.shortUniqueTrackingTag) { params.su = optionalParams.shortUniqueTrackingTag; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("apa", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Application Removed message to Kontagent.
		*
		* @param {Number} userId The UID of the removing user
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackApplicationRemoved(userId:Number, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {s: userId};

			if (optionalParams) {
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("apr", params, successCallback, errorCallback);
		}

		/*
		* Sends an Third Party Communication Click message to Kontagent.
		*
		* @param {String} type The third party comm click type (ad, partner).
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.shortUniqueTrackingTag] 8-digit hex string used to match 
		*	ThirdPartyCommClicks->ApplicationAdded messages. 
		* @param {String} [optionalParams.userId] The UID of the user
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackThirdPartyCommClick(type:String, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				i: 0,
				tu: type
			};
			
			if (optionalParams) {
				if (optionalParams.shortUniqueTrackingTag) { params.su = optionalParams.shortUniqueTrackingTag; }
				if (optionalParams.userId) { params.s = optionalParams.userId; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("ucc", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Page Request message to Kontagent.
		*
		* @param {Number} userId The UID of the user
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {int} [optionalParams.ipAddress] The current users IP address
		* @param {String} [optionalParams.pageAddress] The current page address (ex: index.html)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackPageRequest(userId:Number, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				s: userId,
				ts: this.getTimestamp()
			};
			
			if (optionalParams) {
				if (optionalParams.ipAddress) { params.ip = optionalParams.ipAddress; }
				if (optionalParams.pageAddress) { params.u = optionalParams.pageAddress; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("pgr", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an User Information message to Kontagent.
		*
		* @param {Number} userId The UID of the user
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {int} [optionalParams.birthYear] The birth year of the user
		* @param {String} [optionalParams.gender] The gender of the user (m,f,u)
		* @param {String} [optionalParams.country] The 2-character country code of the user
		* @param {int} [optionalParams.friendCount] The friend count of the user
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackUserInformation(userId:Number, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {s: userId};
			
			if (optionalParams) {
				if (optionalParams.birthYear) { params.b = optionalParams.birthYear; }
				if (optionalParams.gender) { params.g = optionalParams.gender; }
				if (optionalParams.country) { params.lc = optionalParams.country.toUpperCase(); }
				if (optionalParams.friendCount) { params.f = optionalParams.friendCount; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("cpu", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Goal Count message to Kontagent.
		* @param {Number} userId The UID of the user
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {int} [optionalParams.goalCount1] The amount to increment goal count 1 by
		* @param {int} [optionalParams.goalCount2] The amount to increment goal count 2 by
		* @param {int} [optionalParams.goalCount3] The amount to increment goal count 3 by
		* @param {int} [optionalParams.goalCount4] The amount to increment goal count 4 by
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Func`tion} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackGoalCount(userId:Number, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {s: userId};
			
			if (optionalParams) {
				if (optionalParams.goalCount1) { params.gc1 = optionalParams.goalCount1; }
				if (optionalParams.goalCount2) { params.gc2 = optionalParams.goalCount2; }
				if (optionalParams.goalCount3) { params.gc3 = optionalParams.goalCount3; }
				if (optionalParams.goalCount4) { params.gc4 = optionalParams.goalCount4; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("gci", params, successCallback, errorCallback);
		}
		
		/*
		* Sends an Revenue message to Kontagent.
		*
		* @param {Number} userId The UID of the user
		* @param {int} value The amount of revenue in cents
		* @param {Object} [optionalParams] An associative array containing paramName => value
		* @param {String} [optionalParams.type] The transaction type (direct, indirect, advertisement, credits, other)
		* @param {String} [optionalParams.subtype1] Subtype1 value (max 32 chars)
		* @param {String} [optionalParams.subtype2] Subtype2 value (max 32 chars)
		* @param {String} [optionalParams.subtype3] Subtype3 value (max 32 chars)
		* @param {string} [optionalParams.data] Additional JSON-formatted data to associate with the message
		* @param {Function} [successCallback] The callback function to execute once message has been sent successfully
		* @param {Function(error:String)} [errorCallback] The callback function to execute on validation failure 
		*/
		public function trackRevenue(userId:Number, value:int, optionalParams:Object = null, successCallback:Function = null, errorCallback:Function = null):void 
		{
			var params:Object = {
				s: userId,
				v: value
			};
			
			if (optionalParams) {
				if (optionalParams.type) { params.tu = optionalParams.type; }
				if (optionalParams.subtype1) { params.st1 = optionalParams.subtype1; }
				if (optionalParams.subtype2) { params.st2 = optionalParams.subtype2; }
				if (optionalParams.subtype3) { params.st3 = optionalParams.subtype3; }
				if (optionalParams.data) { params.data = this.base64Encode(optionalParams.data); }
			}
			
			return this.sendMessage("mtu", params, successCallback, errorCallback);
		}
	}
}

