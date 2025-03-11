To build a binary using tebako:
$ rake clean
$ rake build
... there should now be a fig gem in pkg/fig-*.gem ...
$ docker ... tebako press --patchelf --root=oss-fig/pkg --entry-point=fig --output=fig-package
