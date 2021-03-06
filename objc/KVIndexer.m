#import "KVIndexer.h"

#include "sfts.h"

enum {
    KVDBIOErrorCode = -2,
    KVDBNotFoundErrorCode = -1,
};

@implementation KVIndexer {
    sfts * _db;
}

- (id) initWithPath:(NSString *)path
{
    self = [super init];
    _path = [path copy];
    _db = sfts_new([_path fileSystemRepresentation]);
    return self;
}

- (BOOL) open
{
    int r = sfts_open(_db);
    if (r < 0) {
        return NO;
    }
    return YES;
}

- (void) close
{
    sfts_close(_db);
}

- (BOOL) flush
{
    int r = sfts_flush(_db);
    if (r < 0) {
        return NO;
    }
    return YES;
}

- (BOOL) setString:(NSString *)string forDocID:(uint64_t)docID
{
    unichar * buffer = malloc(sizeof(* buffer) * ([string length] + 1));
    [string getCharacters:buffer range:NSMakeRange(0, [string length])];
    buffer[[string length]] = 0;
    int r = sfts_u_set(_db, docID, buffer);
    free(buffer);
    if (r == KVDBIOErrorCode) {
        NSLog(@"[%@]: I/O error indexing document \"%llu\"", self, (unsigned long long) docID);
        return NO;
    }
    else if (r < 0) {
        return NO;
    }
    else {
        return YES;
    }
}

- (BOOL) setStrings:(NSArray * /* NSString */)strings forDocID:(uint64_t)docID
{
    UChar ** table = malloc(sizeof(* table) * [strings count]);
    for(unsigned int i = 0 ; i < [strings count] ; i ++) {
        unichar * buffer = malloc(sizeof(* buffer) * ([strings[i] length] + 1));
        table[i] = buffer;
        [strings[i] getCharacters:buffer range:NSMakeRange(0, [strings[i] length])];
        buffer[[strings[i] length]] = 0;
    }
    int r = sfts_u_set2(_db, docID, (const UChar **) table, (int) [strings count]);
    for(unsigned int i = 0 ; i < [strings count] ; i ++) {
        free(table[i]);
    }
    free(table);
    if (r == KVDBIOErrorCode) {
        NSLog(@"[%@]: I/O error indexing document \"%llu\"", self, (unsigned long long) docID);
        return NO;
    }
    else if (r < 0) {
        return NO;
    }
    else {
        return YES;
    }
}

- (void) removeDocID:(uint64_t)docID
{
    int r = sfts_remove(_db, docID);
    if (r == KVDBIOErrorCode) {
        NSLog(@"[%@]: I/O error removing indexed document \"%llu\"", self, (unsigned long long) docID);
    }
}

- (NSArray *) search:(NSString *)token kind:(KVIndexerSearchKind)kind
{
    uint64_t * docids = NULL;
    size_t count = 0;
    UChar * buffer = malloc(sizeof(* buffer) * ([token length] + 1));
    [token getCharacters:buffer range:NSMakeRange(0, [token length])];
    int r = sfts_u_search(_db, buffer, (sfts_search_kind) kind, &docids, &count);
    free(buffer);
    if (r == KVDBIOErrorCode) {
        NSLog(@"[%@]: I/O error searching for token \"%@\"", self, token);
        return nil;
    }
    else if (r < 0) {
        return nil;
    }
    
    NSMutableArray * result = [NSMutableArray array];
    for(size_t i = 0 ; i < count ; i ++) {
        [result addObject:[NSNumber numberWithUnsignedLongLong:docids[i]]];
    }
    free(docids);
    
    return result;
}


@end
