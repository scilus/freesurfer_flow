# FreeSurfer pipeline
===================

Run the FreeSurfer recon-all pipeline and create the customize freesurfer,
brainnetome and glasser connectivity atlas in native space.

If you use this pipeline, please cite:

```
Fischl, Bruce. "FreeSurfer." Neuroimage 62.2 (2012)
https://dx.doi.org/10.1016%2Fj.neuroimage.2012.01.021

Kurtzer GM, Sochat V, Bauer MW Singularity: Scientific containers for
mobility of compute. PLoS ONE 12(5): e0177459 (2017)
https://doi.org/10.1371/journal.pone.0177459

P. Di Tommaso, et al. Nextflow enables reproducible computational workflows.
Nature Biotechnology 35, 316–319 (2017) https://doi.org/10.1038/nbt.3820
```

Requirements
------------

- [Nextflow](https://www.nextflow.io)
- [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/)
- [scilpy](https://github.com/scilus/scilpy)


Singularity/Docker
-----------
If you are on Linux, we recommend using the Singularity to run tractometry_flow pipeline.
If you have Apptainer (Singularity), launch your Nextflow command with:
`-with-singularity ABSOLUTE_PATH/scilus-freesurfer-2.1.0.sif`

Image is available [here](http://scil.dinf.usherbrooke.ca/en/containers_list/scilus-freesurfe_2.1.0.sif)

If you are on MacOS or Windows, we recommend using the Docker container to run tractometry_flow pipeline.
Launch your Nextflow command with:
`-with-docker scilus/scilus-freesurfer:2.1.0`

:warning: WARNING :warning:
---------
The official release 2.1.0 is **NOT** available now.

Please, either build the singularity container using this command:

`singularity build scilus-freesurfer-dev.sif docker://scilus/scilus-freesurfer:dev` 

and then launch your Nextflow command with:
`-with-singularity ABSOLUTE_PATH/scilus-freesurfer_dev.sif`

Or launch your Nextflow command with docker:
`-with-docker scilus/scilus-freesurfer:dev`


Usage
-----

See *USAGE* or run `nextflow run main.nf --help`
