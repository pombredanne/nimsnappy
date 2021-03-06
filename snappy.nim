
{.deadCodeElim: on.}

when defined(windows): 
  const 
    libsnappy* = "libsnappy.dll"
elif defined(macosx): 
  const 
    libsnappy* = "libsnappy.dylib"
else: 
  const 
    libsnappy* = "libsnappy.so.1"

type
  snappy_status* {.size: sizeof(cint).} = enum
    ## Snappy operations result status
    SNAPPY_OK = 0
    SNAPPY_INVALID_INPUT = 1
    SNAPPY_BUFFER_TOO_SMALL = 2

  csize* = int


proc snappy_compress*(input: cstring;
                      input_length: csize;
                      compressed:  cstring;
                      compressed_length: ptr csize): snappy_status {.cdecl,
    importc: "snappy_compress", dynlib: libsnappy.} ##\
    ##Takes the data stored in "input[0..input_length-1]" and stores
    ##it in the array pointed to by "compressed".
    ## 
    ##<compressed_length> signals the space available in "compressed".
    ##If it is not at least equal to "snappy_max_compressed_length(input_length)",
    ##`SNAPPY_BUFFER_TOO_SMALL` is returned. After successful compression,
    ##<compressed_length> contains the true length of the compressed output,
    ##and `SNAPPY_OK` is returned.
    
proc snappy_uncompress*(compressed: cstring;
                        compressed_length: csize;
                        uncompressed: cstring;
                        uncompressed_length: ptr csize): snappy_status {.
    cdecl, importc: "snappy_uncompress", dynlib: libsnappy.} ##\
    ##Given data in "compressed[0..compressed_length-1]" generated by
    ##calling the snappy_compress routine, this routine stores
    ##the uncompressed data to
    ##  uncompressed[0..uncompressed_length-1].
    ##Returns failure (a value not equal to SNAPPY_OK) if the message
    ##is corrupted and could not be decrypted.
    ## 
    ##<uncompressed_length> signals the space available in "uncompressed".
    ##If it is not at least equal to the value returned by
    ##snappy_uncompressed_length for this stream, SNAPPY_BUFFER_TOO_SMALL
    ##is returned. After successful decompression, <uncompressed_length>
    ##contains the true length of the decompressed output.
 
proc snappy_max_compressed_length*(source_length: csize): csize {.cdecl,
    importc: "snappy_max_compressed_length", dynlib: libsnappy.} ##\
    ##Returns the maximal size of the compressed representation of
    ##input data that is "source_length" bytes in length.

proc snappy_uncompressed_length*(compressed: cstring;
                                 compressed_length: csize;
                                 result: ptr csize): snappy_status {.cdecl,
    importc: "snappy_uncompressed_length", dynlib: libsnappy.} ##\
    ##REQUIRES: "compressed[]" was produced by snappy_compress()
    ##Returns SNAPPY_OK and stores the length of the uncompressed data in
    ##*result normally. Returns SNAPPY_INVALID_INPUT on parsing error.
    ##This operation takes O(1) time.

proc snappy_validate_compressed_buffer*(compressed: cstring;
                                       compressed_length: csize): snappy_status {.
    cdecl, importc: "snappy_validate_compressed_buffer", dynlib: libsnappy.} ##\
    ##Check if the contents of "compressed[]" can be uncompressed successfully.
    ##Does not return the uncompressed data; if so, returns SNAPPY_OK,
    ##or if not, returns SNAPPY_INVALID_INPUT.
    ##Takes time proportional to compressed_length, but is usually at least a
    ##factor of four faster than actual decompression.

#
# Nim high level API
#

type
  SnappyException* = object of Exception
    
proc compress*(input:string):string =
  ## Compress a string using snappy.
  var
    output_length = snappy_max_compressed_length(input.len) 
    output = newString(output_length)
  
  let status = snappy_compress(input,
                               input.len,
                               output,
                               addr (output_length))
  
  if status != snappy_status.SNAPPY_OK:
    raise newException(SnappyException,$status)

  # set length of our output string
  # since `snappy_max_compressed_length()` gives us an upper
  # bound the the length
  output.setLen(output_length)
  result = output
  
proc uncompress*(input:string):string =
  ## Uncompress a string. The input string has to be
  ## a string compressed by `snappy`
  let can_uncompress = snappy_validate_compressed_buffer(input, input.len)
  if can_uncompress != snappy_status.SNAPPY_OK:
    raise newException(SnappyException,
                       "Malformed compressed input: " & $can_uncompress)
  
  var
    output_length:int = 0
    status = snappy_uncompressed_length(input,
                                        input.len,
                                        addr output_length)
  if status != snappy_status.SNAPPY_OK:
    raise newException(SnappyException,$status)

  var output = newString(output_length)
  status = snappy_uncompress(input,
                             input.len,
                             output,
                             addr output_length)

  if status != snappy_status.SNAPPY_OK:
    raise newException(SnappyException,$status)

  result = output
