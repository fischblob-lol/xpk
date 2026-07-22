
Xbuild's
=============
We have made it very easy to package on XPK. Following this guide, it should be a breeze!

Xbuild files use a TOML-like format.

What is TOML?
-------------
In a nutshell, TOML is an easy to write config file format designed for humans. 

We can use TOML to package .xbuild files. It is very simple, here is an example for TOML:

.. code-block:: TOML

	# This is a TOML document

	title = "TOML Example"

	[owner]
	name = "Tom Preston-Werner"
	dob = 1979-05-27T07:32:00-08:00
	
	[database]
	enabled = true
	ports = [ 8000, 8001, 8002 ]
	data = [ ["delta", "phi"], [3.14] ]
	temp_targets = { cpu = 79.5, case = 72.0 }
	
	[servers]

	[servers.alpha]
	ip = "10.0.0.1"
	role = "frontend"
	
	[servers.beta]
	ip = "10.0.0.2"
	role = "backend"

Simple, right?

Now, .xbuild files have the same TOML like syntax.

Xbuild cheatsheet
-----------------
Here is a cheatsheet for all the categories and names.

+----------------+--------------+-------------------------+-----------+
| Category       | Name         | Purpose / meaning       | Required? |
+================+==============+=========================+===========+
| Info           | homepage     | Github repo             | Yes       |
+----------------+--------------+-------------------------+-----------+
| Info           | upstream     | Maintainer              | No        |
+----------------+--------------+-------------------------+-----------+
| Info           | name         | Name of the package     | Yes       |
+----------------+--------------+-------------------------+-----------+
| Info           | version      | Version of the package  | Yes       |
+----------------+--------------+-------------------------+-----------+
| Info           | desc         | A brief description     | Yes       |
|                |              | of the package          |           |
+----------------+--------------+-------------------------+-----------+
| Info           | deps         | (array) Dependencies    | Yes,      |
|                |              | of the package          | if none:  |
|                |              |                         | just put  |
|                |              |                         | it as '[]'|
+----------------+--------------+-------------------------+-----------+
| pkg            | src-url      | Link to the source      | Yes       |
|                |              | tarball                 |           |
+----------------+--------------+-------------------------+-----------+
| pkg            | sha256       | SHA256sum of the source | Yes       |
|                |              | tarball                 |           |
+----------------+--------------+-------------------------+-----------+
| pkg            | strip        | (integer) How many      | No        |
|                |              | folders to strip        |           |
+----------------+--------------+-------------------------+-----------+
| pkg            | pre-hooks    | (array) (string) (shell)| Yes,      |
|                |              | Pre hooks (just shell)  | if none:  |
|                |              |                         | just put  |
|                |              |                         | it as '[]'|
+----------------+--------------+-------------------------+-----------+
| build          | build-sys    | Build system            | Yes       |
+----------------+--------------+-------------------------+-----------+
| build          | script       | optional variable incase| Yes,      |
|                |              | scripts need to be ran  | if none:  |
|                |              |                         | just put  |
|                |              |                         | it as '[]'|
+----------------+--------------+-------------------------+-----------+
| build          | post-hooks   | (array) (string) (shell)| Yes,      |
|                |              | Post hooks (just shell) | if none:  |
|                |              |                         | just put  |
|                |              |                         | it as '[]'|
+----------------+--------------+-------------------------+-----------+
