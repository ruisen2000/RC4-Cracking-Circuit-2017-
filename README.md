RC4 Cracking Circuit
RC4 is a stream cipher for encrypting web data. 
This circuit uses multiple cores in parallel to crack the stream cypher and determine the secret key using brute force.  The Circuit will try every possible key in the keyspace and stop when the correct key is found (correct key is defined by a decoded message where every character is in the range [97,122], which corresponds to the characters a-z.  Each of the 4 cores will search 1/4 of the total keyspace.   The decoded message is then written to ROM.

The secret key is set using the slider switches on the Altera FPGA.

Algorithm:

// Input:

// secret_key [] : array of bytes that represent the secret key. In this implementation,
// we will assume a key of 24 bits, meaning this array is 3 bytes long

// encrypted_input []: array of bytes that represent the encrypted message. In our
implementation, we will assume the input message is 32 bytes

// Output:

// decrypted _output []: array of bytes that represent the decrypted result. This will
// always be the same length as encrypted_input [].                                                                                     
// initialize s array. (Task 1)


for i = 0 to 255 {  
  s[i] = i;  
}

// shuffle the array based on the secret key. You will build this in Task 2  
j = 0  
for i = 0 to 255 {  
  j = (j + s[i] + secret_key[i mod keylength] ) mod 256 //keylength is 3 in our impl.  
  swap values of s[i] and s[j]  
}  

// compute one byte per character in the encrypted message. You will build this in Task 2  
i = 0, j=0  
for k = 0 to message_length-1 { // message_length is 32 in our implementation  
  i = (i+1) mod 256  
  j = (j+s[i]) mod 256  
  swap values of s[i] and s[j]  
  f = s[ (s[i]+s[j]) mod 256 ]  
  decrypted_output[k] = f xor encrypted_input[k] // 8 bit wide XOR function  
}
