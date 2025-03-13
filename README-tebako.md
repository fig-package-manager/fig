To build a binary using tebako:
...start a shell on an linux/amd64 host with docker...
$ rake clean
$ rake build
... there should now be a fig gem in pkg/fig-*.gem ...
$ docker ... tebako press --patchelf --root=oss-fig/pkg --entry-point=fig --output=fig-package


For docker image for ubuntu, choose either of
1. ghcr.io/tamatebako/tebako-ubuntu-20.04:latest

   You will need to `docker login` to `ghcr.io`, which requires a github PAT.
   
2. artifacts.drwholdings.com/ghcr-docker-remote/tamatebako/tebako-ubuntu-20.04:latest

   DRW's pull-through artifactory cache of ghcr.io requiring no
   authentication or token.


