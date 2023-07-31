#!/bin/bash
set -eo pipefail

# -------- functions ------------ #

function readFile() {
    # Read the file
    file="$(pwd)/dependencies.yaml" # use absolute path

    # Get the number of dependencies
    count=$(yq e '.dependencies | length' $file)

}

function checkHelmDependenciesAndUpdateWithOutPR() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do
        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | tr -d ' ' | tr '/' '-')

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        # Output
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            if [ ! $(git branch --list update-helm-$sanitized_name-$current_version) ]; then
                echo "There's a difference between the versions."

                # Get values from the repo
                values=$(helm show values $repo_name --version $version)
                echo "$values" >values.yaml
                current_values=$(helm show values $repo_name --version $current_version)
                echo "$current_values" >current_values.yaml

                diff_result=$(dyff between values.yaml current_values.yaml) || true
                # Output differences
                echo "$diff_result" >diff_result.txt
                awk '{ printf "\t%s\n", $0 }' diff_result.txt >shift_diff_result.txt
                shift_diff_result=$(cat shift_diff_result.txt)

                # Delete the temporary files
                rm values.yaml current_values.yaml diff_result.txt shift_diff_result.txt

                # Replace the old version with the new version in the Chart.yaml file using sed
                sed -i.bak "s/version: $version/version: $current_version/g" "$(basename $chart_file)" && rm "$(basename $chart_file).bak"

                # Create a new branch for this change
                git checkout -b update-helm-$sanitized_name-$current_version
                # Add the changes to the staging area
                git add "$(basename $chart_file)"

                # Create a commit with a message indicating the changes
                git commit -m "Update $name version from $version to $current_version"

                # Push the new branch to GitHub
                git push origin update-helm-$sanitized_name-$current_version

                # Get back to the source branch
                git checkout $BRANCH

            else
                echo "Branch already exists. Checking out to the existing branch." || true
            fi

        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
    done

}
function checkHelmDependenciesAndUpdateGitHub() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do
        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | tr -d ' ' | tr '/' '-')

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        # Output
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            if [ ! $(git branch --list update-helm-$sanitized_name-$current_version) ]; then
                echo "There's a difference between the versions."

                # Get values from the repo
                values=$(helm show values $repo_name --version $version)
                echo "$values" >values.yaml
                current_values=$(helm show values $repo_name --version $current_version)
                echo "$current_values" >current_values.yaml

                diff_result=$(dyff between values.yaml current_values.yaml) || true
                # Output differences
                echo "$diff_result" >diff_result.txt
                awk '{ printf "\t%s\n", $0 }' diff_result.txt >shift_diff_result.txt
                shift_diff_result=$(cat shift_diff_result.txt)

                # Delete the temporary files
                rm values.yaml current_values.yaml diff_result.txt shift_diff_result.txt

                # Replace the old version with the new version in the Chart.yaml file using sed
                sed -i.bak "s/version: $version/version: $current_version/g" "$(basename $chart_file)" && rm "$(basename $chart_file).bak"

                # Create a new branch for this change
                git checkout -b update-helm-$sanitized_name-$current_version
                # Add the changes to the staging area
                git add "$(basename $chart_file)"

                # Create a commit with a message indicating the changes
                git commit -m "Update $name version from $version to $current_version"

                # Push the new branch to GitHub
                git push origin update-helm-$sanitized_name-$current_version

                # Create a GitHub Pull Request
                gh pr create --title "Update $name version from $version to $current_version" --body "$shift_diff_result" --base main --head update-helm-$sanitized_name-$current_version || true

                # Get back to the source branch
                git checkout $BRANCH

            else
                echo "Branch already exists. Checking out to the existing branch." || true
            fi

        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
    done

}
function checkHelmDependenciesAndUpdateAzureDevOps() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do
        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | tr -d ' ' | tr '/' '-')

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        # Output
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            if [ ! $(git branch --list update-helm-$sanitized_name-$current_version) ]; then
                echo "There's a difference between the versions."

                # Get values from the repo
                values=$(helm show values $repo_name --version $version)
                echo "$values" >values.yaml
                current_values=$(helm show values $repo_name --version $current_version)
                echo "$current_values" >current_values.yaml

                diff_result=$(dyff between values.yaml current_values.yaml) || true
                # Output differences
                echo "$diff_result" >diff_result.txt
                awk '{ printf "\t%s\n", $0 }' diff_result.txt >shift_diff_result.txt
                shift_diff_result=$(cat shift_diff_result.txt)

                # If the diff output is too large for display, overwrite it with a message
                if ((${#shift_diff_result} > 4000)); then
                    shift_diff_result="The diff output is too large for display (>4000 characters). Please refer to ArtifactHub directly for a detailed comparison of changes between the $version and $current_version."
                fi

                # Delete the temporary files
                rm values.yaml current_values.yaml diff_result.txt shift_diff_result.txt

                # Replace the old version with the new version in the Chart.yaml file using sed
                sed -i.bak "s/version: $version/version: $current_version/g" "$(basename $chart_file)" && rm "$(basename $chart_file).bak"

                # Create a new branch for this change
                git checkout -b update-helm-$sanitized_name-$current_version
                # Add the changes to the staging area
                git add "$(basename $chart_file)"

                # Create a commit with a message indicating the changes
                git commit -m "Update $name version from $version to $current_version"

                # Push the new branch to GitHub
                git push origin update-helm-$sanitized_name-$current_version

                # Create a Azure DevOps Pull Request
                az repos pr create --title "Update $name version from $version to $current_version" --description "$shift_diff_result" --target-branch $BRANCH --source-branch update-helm-$sanitized_name-$current_version 1>/dev/null || true

                # Get back to the source branch
                git checkout $BRANCH

            else
                echo "Branch already exists. Checking out to the existing branch." || true
            fi

        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
    done

}

function checkHelmDependenciesAndUpdateDryRun() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do

        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | tr -d ' ' | tr '/' '-')

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        # Output
        echo "####################### Begin #######################"
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            echo "There's a difference between the versions."

            # Get values from the repo
            values=$(helm show values $repo_name --version $version)
            echo "$values" >values.yaml
            current_values=$(helm show values $repo_name --version $current_version)
            echo "$current_values" >current_values.yaml

            diff_result=$(dyff between values.yaml current_values.yaml) || true
            echo "$diff_result"

            # Delete the temporary files
            rm values.yaml current_values.yaml
        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
        echo "####################### End #######################"
    done

}

function errorEcho {
    echo "ERROR: ${1}" 1>&2
    exit 1
}

function infoEcho {
    echo "${1}"
}

function errorUsage {

    echo "+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                                 ERROR: ${1}                                    |
 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  "
    usage
    exit 1
}

function usage() {
    echo "


  "
    echo ""
    echo "please set all necessary environments like export BRANCH='main' "
    echo "--------------- necessary-Variables: -------------------"
    echo "BRANCH:'main'"
    echo "DRY_RUN:'false'"
    echo "GITHUB:'false'"
    echo "AZURE_DEVOPS:'false'"
    echo "WITHOUT_PR:'true'"
    echo ""
}

function start() {
    # Read the file
    readFile
    # Check if the dependencies are up to date
    if [ "$DRY_RUN" == "true" ]; then
        checkHelmDependenciesAndUpdateDryRun
    fi
    if [ "$WITHOUT_PR" == "true" ]; then
        checkHelmDependenciesAndUpdateWithOutPR
    fi
    if [ "$GITHUB" == "true" ]; then
        checkHelmDependenciesAndUpdateGitHub
    fi
    if [ "$AZURE_DEVOPS" == "true" ]; then
        checkHelmDependenciesAndUpdateAzureDevOps
    fi
}

# -------- Check Prerequisites ------------ #

for cmd in gh yq dyff az helm git; do
    command -v ${cmd} >/dev/null || {
        echo >&2 "${cmd} must be installed - exiting..."
        exit 1
    }
done

while [[ $# -gt 0 ]]; do
    key="${1}"

    case $key in
    --help | -h | help)
        usage
        exit 0
        ;;
    *)
        shift
        ;;
    esac
done

# -------- Load config ------------ #

# load env file if present
if [[ -f "${PWD}/config.env" ]]; then
    source "${PWD}/config.env"
else
    errorEcho "Config file ${PWD}/config.env doesnt exists. Please use init-config command to create the file!"
fi

# -------- environments check  ------------ #

## Abort if required arguments are empty
if [[ -z ${BRANCH} || ${BRANCH} == '<no value>' ]]; then
    errorUsage "BRANCH missing!"
fi

if [[ -z ${DRY_RUN} || ${DRY_RUN} == '<no value>' ]]; then
    errorUsage "DRY_RUN missing!"
fi

if [[ -z ${GITHUB} || ${GITHUB} == '<no value>' ]]; then
    errorUsage "GITHUB missing!"
fi

if [[ -z ${AZURE_DEVOPS} || ${AZURE_DEVOPS} == '<no value>' ]]; then
    errorUsage "AZURE_DEVOPS missing!"
fi

if [[ -z ${WITHOUT_PR} || ${WITHOUT_PR} == '<no value>' ]]; then
    errorUsage "WITHOUT_PR missing!"
fi

# -------- Main  ------------ #
start
