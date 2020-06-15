#!/usr/bin/env nextflow

params.root_fs_input = false
params.root_fs_output = false
params.help = false


if(params.help) {
    usage = file("$baseDir/USAGE")

    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["nb_threads":"$params.nb_threads"]
    bindings = ["atlas_utils_folder":"$params.atlas_utils_folder"]
    bindings = ["brainstem_structures":"$params.brainstem_structures"]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)

    print template.toString()
    return
}

log.info "Run Freesurfer"
log.info "========================="
log.info ""

log.debug "[Command-line]"
log.debug "$workflow.commandLine"
log.debug ""
log.debug "Thanks to Félix C. Morency from imeka.ca for the inspiration."

log.info "[Inputs]"
log.info "Root FS Input: $params.root_fs_input"
log.info "Root FS Output: $params.root_fs_output"

if (params.root_fs_input) {
root_fs_input = file(params.root_fs_input)
in_files = Channel.fromPath("$root_fs_input/**/*t1.nii.gz")
    .map{ch1 -> [ch1.parent.name, ch1]}
}
else {
    in_files = Channel.empty()
}

if (params.root_fs_output) {
root_fs_output = file(params.root_fs_output)
in_folders = Channel.fromPath("$root_fs_output/*/", type: 'dir')
    .map{ch1 -> [ch1.name, ch1]}
}
else {
    in_folders = Channel.empty()
}

atlas_utils_folder = Channel.fromPath("$params.atlas_utils_folder")

process Recon_All {
    cpus params.nb_threads

    input:
    set sid, file(anat) from in_files

    output:
    set sid, "$sid/" into folders_for_atlases

    script:
    """
    export SUBJECTS_DIR=.
    if ${params.brainstem_structures}; then
        recon-all -i $anat -s $sid -all -parallel -openmp $params.nb_threads -brainstem-structures
    else
        recon-all -i $anat -s $sid -all -parallel -openmp $params.nb_threads
    fi
    """
}

in_folders
    .concat(folders_for_atlases)
    .combine(atlas_utils_folder)
    .set{all_folders_for_atlases}
process Generate_Atlases {
    cpus params.nb_threads

    input:
    set sid, file(folder), file(utils) from all_folders_for_atlases

    output:
    set sid, "$sid/FS_BN_GL_Atlas/"

    script:
    """
    echo ${folder}
    if ${params.brainstem_structures}; then
        version=FS_BN_GL_utils_with_brainstem_structures
    else
        version=FS_BN_GL_utils_without_brainstem_structures
    fi
    ln -s ${utils}/fsaverage \$(dirname ${folder})/
    bash ${utils}/\${version}/generate_atlas_BN_FS_v2.sh \$(dirname ${folder}) ${sid} ${params.nb_threads} FS_BN_GL_Atlas/
    """
}
