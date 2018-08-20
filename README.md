RC4 Cracking Circuit
RC4 is a stream cipher for encrypting web data. 
This circuit uses multiple cores in parallel to crack the stream cypher and determine the secret key using brute force.  The Circuit will try every possible key in the keyspace and stop when the correct key is found (correct key is defined by a decoded message where every character is in the range [97,122], which corresponds to the characters a-z.  Each of the 4 cores will search 1/4 of the total keyspace.   The decoded message is then written to ROM.

The secret key is set using the slider switches on the Altera FPGA.
