# ci docker images

this directory contains docker images used for continuous integration and testing in oss-fig.

currently available images:
- `centos7.9.2009` - centos 7.9.2009 image for testing gem installation

## usage

these images are published to github container registry (ghcr.io) and can be used in github actions workflows:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/your-org/oss-fig/fig-ci:centos7.9.2009
```

## rebuilding

the images are automatically built and published when changes are made to the dockerfile or related files.

to manually trigger a build, use the github actions "build ci docker images" workflow.
