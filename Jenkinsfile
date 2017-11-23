def pipeline

node('q2c') {
	stage('Setting_Variables') {
	  // Set Variables needed by Jenkins
	  env.githubRepoUrl = 'git@github.devtools.merrillcorp.com:Q2C/q2c-project.git'
	  env.cloudhubAppName = 'mrll-dev-q2c-project'
	  env.buildChanges = "${env.BUILD_URL}" + "changes"
	  env.htmlStart = "<b>${env.cloudhubAppName}</b><br /><h4>Is Beginning Build Number <i>${env.BUILD_ID}</i></h4><br /><a href=${env.BUILD_URL}>Build Status</a>"
	  env.htmlEnd = "<b>${env.cloudhubAppName}</b><br /><h4>Has Successfully Completed Build Number <i>${env.BUILD_ID}</i></h4><br /><a href=${env.buildChanges}>Build Changes</a>"
	}
	stage('Notify_Build_Starting') {
	    hipchatSend color: 'YELLOW', credentialId: 'HipChat-API-Token', message: "${env.htmlStart}", notify: true, room: "Mule_${PIPELINE_ENV}_Builds", sendAs: '', server: '', v2enabled: false
	}
	
	stage('Execute_Pipeline'){
	  // Fetch and execute template
	  git url: 'git@github.devtools.merrillcorp.com:Q2C/jenkins-templates.git'
	  pipeline = load 'jenkins-pipeline-tools.groovy'
	  pipeline.mulePipeline()
	}
	
	stage('CleanUp_and_Notify') {
	    hipchatSend color: 'GREEN', credentialId: 'HIPCHAT_NOTIFS', message: "${env.htmlEnd}", notify: true, room: "Mule_${PIPELINE_ENV}_Builds", sendAs: '', server: '', v2enabled: false
	}
}