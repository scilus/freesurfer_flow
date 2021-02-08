#!/usr/bin/env nextflow

if(params.help) {
    usage = file("$baseDir/USAGE")

    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["nb_threads":"$params.nb_threads",
                "atlas_utils_folder":"$params.atlas_utils_folder",
                "compute_FS_BN_GL":"$params.compute_FS_BN_GL",
                "compute_lausanne_multiscale":"$params.compute_lausanne_multiscale"]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)

    print template.toString()
    return
}

log.info "Run Freesurfer"
log.info "========================="
log.info ""

log.info ""
log.info "Start time: $workflow.start"
log.info ""

log.debug "[Command-line]"
log.debug "$workflow.commandLine"
log.debug ""

log.info "[Git Info]"
log.info "$workflow.repository - $workflow.revision [$workflow.commitId]"
log.info ""

log.info "[Inputs]"
log.info "Root FS Input: $params.root_fs_input"
log.info "Root FS Output: $params.root_fs_output"

log.info "Options"
log.info "======="
log.info ""
log.info "Number of Thread: $params.nb_threads"
log.info "Atlas Utils Folder: $params.atlas_utils_folder"
log.info ""

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

process Recon_All {
    cpus params.nb_threads

    input:
    set sid, file(anat) from in_files

    output:
    set sid, "$sid/" into folders_for_atlases

    script:
    """
    export SUBJECTS_DIR=.
    recon-all -i $anat -s $sid -all -parallel -openmp $params.nb_threads
    """
}

in_folders
    .concat(folders_for_atlases)
    .into{all_folders_for_atlases_FS_BN_GL;all_folders_for_atlases_lausanne}

process Generate_Atlases_FS_BN_GL_SF {
    cpus params.nb_threads

    input:
    set sid, file(folder) from all_folders_for_atlases_FS_BN_GL

    when:
    params.compute_FS_BN_GL

    output:
    file "*.nii.gz"
    file "*.txt"
    file "*.json"

    script:
    """
    version=freesurfer_utils/
    ln -s $params.atlas_utils_folder/fsaverage \$(dirname ${folder})/
    bash $params.atlas_utils_folder/\${version}/generate_atlas_FS_BN_GL_SF_v3.sh \$(dirname ${folder}) ${sid} ${params.nb_threads} FS_BN_GL_SF_Atlas/

    cp $sid/FS_BN_GL_SF_Atlas/* ./
    """
}

scales = Channel.from(1,2,3,4,5)

process Generate_Atlases_Lausanne {
    cpus 1

    input:
    set sid, file(folder) from all_folders_for_atlases_lausanne
    each scale from scales

    when:
    params.compute_lausanne_multiscale

    output:
    file "lausanne_2008_scale_${scale}.nii.gz"
    file "lausanne_2008_scale_${scale}_dilate.nii.gz"
    file "*.txt"
    file "*.json"

    script:
    """
    ln -s $params.atlas_utils_folder/fsaverage \$(dirname ${folder})/
    freesurfer_home=\$(dirname \$(dirname \$(which mri_label2vol)))
    python3.7 $params.atlas_utils_folder/lausanne_multi_scale_atlas/generate_multiscale_parcellation.py \$(dirname ${folder}) ${sid} \$freesurfer_home --scale ${scale} --dilation_factor 0 --log_level DEBUG

    mrthreshold ${folder}/mri/rawavg.mgz mask.nii.gz -abs 0.001 -quiet
    scil_reshape_to_reference.py ${folder}/mri/lausanne2008.scale${scale}+aseg.nii.gz mask.nii.gz lausanne_2008_scale_${scale}.nii.gz --interpolation nearest
    scil_image_math.py convert lausanne_2008_scale_${scale}.nii.gz lausanne_2008_scale_${scale}.nii.gz --data_type int16 -f
    scil_dilate_labels.py lausanne_2008_scale_${scale}.nii.gz lausanne_2008_scale_${scale}_dilate.nii.gz --distance 2 --mask mask.nii.gz
    
    cp $params.atlas_utils_folder/lausanne_multi_scale_atlas/*.txt ./
    cp $params.atlas_utils_folder/lausanne_multi_scale_atlas/*.json ./
    """
}
