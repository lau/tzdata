##Mozilla Cacert for httpc

Basically the above file is Mozilla CA certificate store created for [curl](https://curl.haxx.se/docs/caextract.html).

I pulled this file in particular because there is convenient [checksum](https://curl.haxx.se/ca/cacert.pem.sha256) on the curl site if someone want to check for security reasons and they provide an easy download link as well as way to generated the file locally if you have firefox and a copy of [curl](https://github.com/curl/curl/blob/master/lib/firefox-db2pem.sh). 


####Is this overkill? 

Part of the reason we have this cacert file is to reduce dependency bloat in more complex applications but really we only need the signing authority that iana uses for tzdata purposes. However, we then could not just download the file if iana decides to change their certs on some fundamental level and it might create more mess to reduce the file to just what is needed (plus we lose the above tooling). We can do this at some point with a bit of research it's just whether or not it's worth research time versus the very small rarely reved file.

I am sure more wisdom will come over time how to handle this but I am content with having a few extra keys for the time being. 
