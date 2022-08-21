# Branching and versioning policy

## Version numbers for Intest

Intest is developed in public. Command-line users comfortable with git can always get the very latest state. But that potentially means endless different versions of Intest out there in the wild. To clarify this situation, all versions are numbered, and we will distinguish between "release" versions, which are ready for public use, and "unstable" versions, which are not.

"Release" versions have simple version numbers in the shape `X.Y.Z`: for example, `2.1.0`.

"Unstable" versions are commits of the software between releases. These have much longer version numbers, containing an `-alpha` or `-beta` warning. For example, `2.1.0-beta+1B14`. (The `+1B14` is a daily build number, also only
present on version numbers of unstable versions.)

Note that `intest -version` prints out the full version number of the core
source it was compiled from. This one is clearly unstable:

	$ intest/Tangled/intest -version
	intest version 2.1.0-beta+1A38 'The Remembering' (31 May 2022)

(It is now unclear why major versions of Intest are named after [the movements of Tales from Topographic Oceans](https://en.wikipedia.org/wiki/Tales_from_Topographic_Oceans).
But such is life, and major version 3 will have to be called "The Ancient".)

Release notes for releases since 2022 can be found [here](version_history.md).

## Branching

In the core Intest repository, active development is on the `master` branch, at least for now. That will always be a version which is unstable. All releases will be made from short branches off of `master`. For example, there will soon be a branch called `r2.1`. This will contain as few commits as possible, ideally just one, which would be the actual release version of 2.1.0. But if there are then point updates with bug fixes, say 2.1.1, 2.1.2, and so on, those would be further commits to the `r2.1` branch. Later, another short branch from `master` would be `r2.2`.

Releases will be tagged with their version numbers, so the commit representing 2.1.0 will be tagged `v2.1.0`. These will be presented under Releases in the usual Github way, from the column on the right-hand side of the home page. We expect to provide the app installers as associated binary files on those releases, though that won't be the only place they are available.
