component extends="preside.system.base.AdminHandler" {

	property name="loginService"          inject="loginService";
	property name="passwordPolicyService" inject="passwordPolicyService";
	property name="sessionStorage"        inject="coldbox:plugin:sessionStorage";
	property name="adminDefaultEvent"     inject="coldbox:setting:adminDefaultEvent";
	property name="messageBox"            inject="coldbox:plugin:messageBox";
	property name="i18n"                  inject="coldbox:plugin:i18n";

	public void function preHandler( event, action, eventArguments ) {
		super.preHandler( argumentCollection = arguments );

		event.setLayout( 'adminLogin' );
	}

	public void function index( event, rc, prc ) {
		if ( Len( Trim( rc.l ?: "" ) ) ) {
			i18n.setFwLocale( Trim( rc.l ) );
		}

		if ( event.isAdminUser() ){
			setNextEvent( url=event.buildAdminLink( linkto=adminDefaultEvent ) );
		}

		if ( loginService.isUserDatabaseNotConfigured() ) {
			event.setView( "/admin/login/firstTimeUserSetup" );
		}
	}

	public void function login( event, rc, prc ) {
		var user         = "";
		var postLoginUrl = event.getValue( name="postLoginUrl", defaultValue="" );
		var unsavedData  = sessionStorage.getVar( "_unsavedFormData", {} );
		var loggedIn     = loginService.logIn(
			  loginId  = event.getValue( name="loginId" , defaultValue="" )
			, password = event.getValue( name="password", defaultValue="" )
		);

		if ( loggedIn ) {
			user = event.getAdminUserDetails();
			event.audit(
				  detail   = "[#user.known_as#] has logged in"
				, source   = "login"
				, action   = "login_success"
				, type     = "user"
				, instance = user.id
			);

			if ( Len( Trim( postLoginUrl ) ) ) {
				sessionStorage.deleteVar( "_unsavedFormData", {} );
				setNextEvent( url=_cleanPostLoginUrl( postLoginUrl ), persistStruct=unsavedData );
			} else {
				setNextEvent( url=event.buildAdminLink( linkto=adminDefaultEvent ) );
			}
		} else {
			setNextEvent( url=event.buildAdminLink( linkto="login" ), persistStruct={
				  postLoginUrl = postLoginUrl
				, message      = "LOGIN_FAILED"
			} );
		}
	}

	public void function firstTimeUserSetupAction( event, rc, prc ) {
		var emailAddress         = rc.email_address ?: "";
		var password             = rc.password ?: "";
		var passwordConfirmation = rc.passwordConfirmation ?: "";

		if ( !Len( Trim( emailAddress ) ) || !Len( Trim( password ) ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login" ), persistStruct={
				  message = "EMPTY_PASSWORD"
				, token   = token
			} );
		}

		if ( password != passwordConfirmation ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login" ), persistStruct={
				  message = "PASSWORDS_DO_NOT_MATCH"
				, token   = token
			} );
		}

		loginService.firstTimeUserSetup( emailAddress=emailAddress, password=password );
		setNextEvent( url=event.buildAdminLink( linkTo="login" ), persistStruct={
			message = "FIRST_TIME_USER_SETUP"
		} );
	}

	public void function logout( event, rc, prc ) {
		var user        = "";

		if ( event.isAdminUser() ) {
			user = event.getAdminUserDetails();

			event.audit(
				  detail   = "[#user.known_as#] has logged out"
				, source   = "logout"
				, action   = "logout_success"
				, type     = "user"
				, instance = user.id
			);

			loginService.logout();
		}

		if ( ( rc.redirect ?: "" ) == "referer" ) {
			setNextEvent( url=cgi.http_referer );
		}

		setNextEvent( url=event.buildAdminLink( linkto="login" ) );
	}

	public void function forgottenPassword( event, rc, prc ) {
		if ( event.isAdminUser() ){
			setNextEvent( url=event.buildAdminLink( linkto=adminDefaultEvent ) );
		}

		event.setView( "/admin/login/forgottenPassword" );
	}

	public void function sendResetInstructions( event, rc, prc ) {
		if ( loginService.sendPasswordResetInstructions( rc.loginId ?: "" ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.forgottenPassword" ), persistStruct={
				message = "PASSWORD_RESET_INSTRUCTIONS_SENT"
			} );
		}

		setNextEvent( url=event.buildAdminLink( linkTo="login.forgottenPassword" ), persistStruct={
			message = "LOGINID_NOT_FOUND"
		} );
	}

	public void function resetPassword( event, rc, prc ) {
		if ( event.isAdminUser() ){
			setNextEvent( url=event.buildAdminLink( linkto=adminDefaultEvent ) );
		}

		if ( !loginService.validateResetPasswordToken( rc.token ?: "" ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.forgottenPassword" ), persistStruct={
				message = "INVALID_RESET_TOKEN"
			} );
		}

		var passwordPolicy = passwordPolicyService.getPolicy( "cms" );
		if ( Len( Trim( passwordPolicy.message ?: "" ) ) ) {
			prc.policyMessage = renderContent( "richeditor", passwordPolicy.message );
		}

		event.setView( "/admin/login/resetPassword" );
	}

	public void function resetPasswordAction( event, rc, prc ) {
		var pw           = rc.password             ?: "";
		var confirmation = rc.passwordConfirmation ?: "";
		var token        = rc.token                ?: "";

		if ( !loginService.validateResetPasswordToken( rc.token ?: "" ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.forgottenPassword" ), persistStruct={
				message = "INVALID_RESET_TOKEN"
			} );
		}

		if ( !Len( Trim( pw ) ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.resetPassword" ), persistStruct={
				  message = "EMPTY_PASSWORD"
				, token   = token
			} );
		}

		if ( pw != confirmation ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.resetPassword" ), persistStruct={
				  message = "PASSWORDS_DO_NOT_MATCH"
				, token   = token
			} );
		}

		if ( !passwordPolicyService.passwordMeetsPolicy( "cms", pw )  ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login.resetPassword" ), persistStruct={
				  message = "PASSWORD_NOT_STRONG_ENOUGH"
				, token   = token
			} );
		}

		if ( loginService.resetPassword( token=token, password=pw ) ) {
			setNextEvent( url=event.buildAdminLink( linkTo="login" ), persistStruct={
				message = "PASSWORD_RESET"
			} );
		}

		setNextEvent( url=event.buildAdminLink( linkTo="login.resetPassword" ), persistStruct={
			  message = "UNKNOWN_ERROR"
			, token   = token
		} );

	}

// private helpers
	private string function _cleanPostLoginUrl( required string postLoginUrl ) {
		var cleaned = Trim( arguments.postLoginUrl );

		cleaned = ReReplace( cleaned, "^(https?://.*?)//", "\1/" );

		return cleaned;
	}
}