//
//  SU7zUnarchiver.m
//  Sparkle
//
//  Created by Roman Zechmeister on 30.10.10.
//  Copyright 2010 Roman Zechmeister. All rights reserved.
//

#import "SU7zUnarchiver.h"
#import "SUUnarchiver_Private.h"


@implementation SU7zUnarchiver

- (void)start {
	[NSThread detachNewThreadSelector:@selector(_extract7z) toTarget:self withObject:nil];
}

+ (BOOL)_canUnarchivePath:(NSString *)path {
	return [[path pathExtension] isEqualToString:@"7z"];
}


- (void)_extract7z {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self performSelectorOnMainThread:@selector(_notifyDelegateOfExtractedLength:) withObject:[NSNumber numberWithLong:0] waitUntilDone:NO];

	
	int readPipe[2];
	if (pipe(readPipe)) {
		goto failure;
	}
	
	pid_t pid = fork();
	
	if (pid == 0) {
		NSString *un7zPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"un7z" ofType:@""];
		
		close(readPipe[0]);
		dup2(readPipe[1], 1);
		
		execl([un7zPath fileSystemRepresentation], [un7zPath fileSystemRepresentation], [archivePath fileSystemRepresentation], [[archivePath stringByDeletingLastPathComponent] fileSystemRepresentation], NULL);
		_exit(1);
	} else if (pid < 0) {
		goto failure;
	} else {
		close(readPipe[1]);
		
		FILE *pipeFile = fdopen(readPipe[0], "r");
		char buffer[50];
		long value;
		
		while (fgets(buffer, 50, pipeFile)) {
			if (strncmp("Processed: ", buffer, 11) == 0) {
				value = atol(buffer + 11);
				[self performSelectorOnMainThread:@selector(_notifyDelegateOfExtractedLength:) withObject:[NSNumber numberWithLong:value] waitUntilDone:NO];
			}
		}
		fclose(pipeFile);
		close(readPipe[0]);

		int exitcode;

		if (waitpid(pid, &exitcode, 0) == -1) {
			goto failure;
		}
		if (WEXITSTATUS(exitcode) != 0) {
			goto failure;
		}
	}
	
	[self performSelectorOnMainThread:@selector(_notifyDelegateOfSuccess) withObject:nil waitUntilDone:NO];
	[pool drain];
	return;
	
failure:
	[self performSelectorOnMainThread:@selector(_notifyDelegateOfFailure) withObject:nil waitUntilDone:NO];
	[pool drain];
}

+ (void)load {
	[self _registerImplementation:self];
}



@end
