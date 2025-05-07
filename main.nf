#!/usr/bin/env nextflow

if(params.help) {
    usage = file("$baseDir/USAGE")

    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["nb_threads":"$params.nb_threads",
                "atlas_utils_folder":"$params.atlas_utils_folder",
                "compute_FS_BN_GL_SF":"$params.compute_FS_BN_GL_SF",
                "compute_lausanne_multiscale":"$params.compute_lausanne_multiscale",
                "output_dir":"$params.output_dir",
		        "cpu_count":"$cpu_count"]
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
log.info "Output Dir: $params.output_dir"
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
    .into{all_folders_for_atlases_FS_BN_GL;all_folders_for_atlases_lausanne;all_folders_for_atlases_lobes}

process Generate_Atlases_FS_BN_GL_SF {
    cpus params.nb_threads

    input:
    set sid, file(folder) from all_folders_for_atlases_FS_BN_GL

    when:
    params.compute_FS_BN_GL_SF

    output:
    file "*[brainnetome,freesurfer,glasser,schaefer]*.nii.gz"
    file "*[brainnetome,freesurfer,glasser,schaefer]*.txt"
    file "*[brainnetome,freesurfer,glasser,schaefer]*.json"

    script:
    """
    ln -s $params.atlas_utils_folder/fsaverage \$(dirname ${folder})/
    bash $params.atlas_utils_folder/freesurfer_utils/generate_atlas_FS_BN_GL_SF_v5.sh \$(dirname ${folder}) ${sid} ${params.nb_threads} FS_BN_GL_SF_Atlas/

    cp $sid/FS_BN_GL_SF_Atlas/* ./
    """
}

process Generate_Atlases_Lobes {
    cpus params.nb_threads

    input:
    set sid, file(folder) from all_folders_for_atlases_lobes

    output:
    file "*lobes*.nii.gz"
    file "*lobes*.txt"
    file "*lobes*.json"

    script:
    """
    mri_convert ${folder}/mri/rawavg.mgz rawavg.nii.gz

    mri_convert ${folder}/mri/wmparc.mgz wmparc.nii.gz
    scil_volume_reslice_to_reference.py wmparc.nii.gz rawavg.nii.gz wmparc.nii.gz --interpolation nearest -f
    scil_volume_math.py convert wmparc.nii.gz wmparc.nii.gz --data_type uint16 -f
    
    mri_convert ${folder}/mri/brainmask.mgz brain_mask.nii.gz
    scil_volume_math.py lower_threshold brain_mask.nii.gz 0.001 brain_mask.nii.gz --data_type uint8 -f
    scil_volume_math.py dilation brain_mask.nii.gz 1 brain_mask.nii.gz -f
    scil_volume_reslice_to_reference.py brain_mask.nii.gz rawavg.nii.gz brain_mask.nii.gz --interpolation nearest -f
    scil_volume_math.py convert brain_mask.nii.gz brain_mask.nii.gz --data_type uint8 -f

    scil_labels_combine.py atlas_lobes_v5.nii.gz --volume_ids wmparc.nii.gz 1003 1012 1014 1017 1018 1019 1020 1024 1027 1028 1032 --volume_ids wmparc.nii.gz 1008 1022 1025 1029 1031 --volume_ids wmparc.nii.gz 1005 1011 1013 1021 --volume_ids wmparc.nii.gz 1001 1006 1007 1009 1015 1015 1030 1033 --volume_ids wmparc.nii.gz 1002 1010 1023 1026 --volume_ids wmparc.nii.gz 8 --volume_ids wmparc.nii.gz 10 11 12 13 17 18 26 28 --volume_ids wmparc.nii.gz 2003 2012 2014 2017 2018 2019 2020 2024 2027 2028 2032 --volume_ids wmparc.nii.gz 2008 2022 2025 2029 2031 --volume_ids wmparc.nii.gz 2005 2011 2013 2021 --volume_ids wmparc.nii.gz 2001 2006 2007 2009 2015 2015 2030 2033 --volume_ids wmparc.nii.gz 2002 2010 2023 2026 --volume_ids wmparc.nii.gz 49 50 51 52 53 54 58 60 --volume_ids wmparc.nii.gz 47 --volume_ids wmparc.nii.gz 16 --merge
    scil_labels_dilate.py atlas_lobes_v5.nii.gz atlas_lobes_v5_dilate.nii.gz --distance 2 --labels_to_dilate 1 2 3 4 5 6 8 9 10 11 12 14 15 --mask brain_mask.nii.gz
    cp $params.atlas_utils_folder/freesurfer_utils/*lobes_v5* ./
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
    python3.10 $params.atlas_utils_folder/lausanne_multi_scale_atlas/generate_multiscale_parcellation.py \$(dirname ${folder}) ${sid} \$freesurfer_home --scale ${scale} --dilation_factor 0 --log_level DEBUG

    mri_convert ${folder}/mri/rawavg.mgz rawavg.nii.gz
    scil_volume_math.py lower_threshold rawavg.nii.gz 0.001 mask.nii.gz --data_type uint8
    scil_volume_reslice_to_reference.py ${folder}/mri/lausanne2008.scale${scale}+aseg.nii.gz mask.nii.gz lausanne_2008_scale_${scale}.nii.gz --interpolation nearest
    scil_volume_math.py convert lausanne_2008_scale_${scale}.nii.gz lausanne_2008_scale_${scale}.nii.gz --data_type int16 -f
    scil_labels_dilate.py lausanne_2008_scale_${scale}.nii.gz lausanne_2008_scale_${scale}_dilate.nii.gz --distance 2 --mask mask.nii.gz
    
    cp $params.atlas_utils_folder/lausanne_multi_scale_atlas/*.txt ./
    cp $params.atlas_utils_folder/lausanne_multi_scale_atlas/*.json ./
    """
}
