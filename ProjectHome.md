DESCRIPTION<p>
This module is inspired in the IPC::PerlSSH module by Paul Evans. It provides Remote Procedure Calls (RPC) via a SSH connection. What made IPC::PerlSSH appealing to me was that</p>

<pre>
No special software is required on the remote end, other than the<br>
ability to run perl nor are any special administrative rights required;<br>
any account that has shell access and can execute the perl binary on<br>
the remote host can use this module.</pre><p>

The only requirement being that automatic SSH autentification between the local and remote hosts has been established. I have tried to expand the capabilities but preserving this feature.</p>
<ul>

<li>Provide <i>Remote Procedure Calls</i> (RPC). Subroutines on the remote side can be called with arbitrary nested structures as arguments from the local side.</li>

<li>The result of a remote call is a<br>
GRID::Machine::Result object.<br>
Among the attributes of such object are the<br>
<tt>results</tt> of the call,<br>
the ouput produced in <tt>stdout</tt> and<br>
<tt>stderr</tt>, <tt>errmsg</tt> etc.<br>
The remote function can produce output without risk of misleading the protocol.</li>

<li>Services for the transference of files are provided</li>
<li>Support for writing and management <i>Remote Modules</i> and the transference of Classes and Modules between machines</li>
<li>An Extensible Protocol</li>
</ul>