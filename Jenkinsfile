#!groovy

properties([
    // Our integration with OBS can only follow one build per OBS project; if
    // multiple builds occur, all running jobs will wait for the last build in
    // the OBS project to complete.  To help avoid confusing waits, disable
    // cuncurrent builds for *this one* job in Jenkins (note: each branch is a
    // separate job).  Other jobs can still run concurrently, but if they use
    // the same OBS project, they will have the extra wait.
    disableConcurrentBuilds(),

    pipelineTriggers([
        // Enable SCM triggering of builds via a webhook, so BitBucket can tell
        // us when we need to check for new commits.
        pollSCM(''),
    ]),
])

// Allow parameterized builds on all branches other than master & production
if ( !env.BRANCH_NAME.equals('master') && !env.BRANCH_NAME.equals('production') ) {
    properties([
        parameters([
            string(defaultValue: 'master', description: 'The branch of the ea-tools repository to use for building; defaults to "master".', name: 'EA_TOOLS_BRANCH')
        ]),
    ])
}

node('tool:OBS && project:EA4') {
    def ea4 = fileLoader.fromGit([
        'jenkins/ea4-lib',
        'ssh://git@enterprise.cpanel.net:7999/ea4/ea-tools.git',
        params.EA_TOOLS_BRANCH ?: 'master',
        env.CREDENTIALS_ID_FOR_MAIN_REPOSITORY_HOST,
        ''
    ])
    ea4.modulino()
}
