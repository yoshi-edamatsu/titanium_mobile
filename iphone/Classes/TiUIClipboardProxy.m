/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUIClipboardProxy.h"
#import "TiUtils.h"
#import "TiApp.h"
#import "TiBlob.h"
#import "TiFile.h"
#import "TiUtils.h"

#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>

typedef enum {
	CLIPBOARD_TEXT,
	CLIPBOARD_URI_LIST,
	CLIPBOARD_IMAGE,
	CLIPBOARD_UNKNOWN
} ClipboardType;

static ClipboardType mimeTypeToDataType(NSString *mimeType)
{
	mimeType = [mimeType lowercaseString];
    
	// Types "URL" and "Text" are for IE compatibility. We want to have
	// a consistent interface with WebKit's HTML 5 DataTransfer.
	if ([mimeType isEqualToString: @"text"] || [mimeType hasPrefix: @"text/plain"])
	{
		return CLIPBOARD_TEXT;
	}
	else if ([mimeType isEqualToString: @"url"] || [mimeType hasPrefix: @"text/uri-list"])
	{
		return CLIPBOARD_URI_LIST;
	}
	else if ([mimeType hasPrefix: @"image"])
	{
		return CLIPBOARD_IMAGE;
	}
	else
	{
		// Something else, work from the MIME type.
		return CLIPBOARD_UNKNOWN;
	}
}

static NSString *mimeTypeToUTType(NSString *mimeType)
{
	NSString *uti = [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)mimeType, NULL) autorelease];
	if (uti == nil) {
		// Should we do this? Lets us copy/paste custom data, anyway.
		uti = mimeType;
	}
	return uti;
}

@implementation TiUIClipboardProxy

-(NSString*)apiName
{
    return @"Ti.UI.Clipboard";
}

-(void)clearData:(id)arg
{
	ENSURE_UI_THREAD(clearData, arg);
	ENSURE_STRING_OR_NIL(arg);

	NSString *mimeType = arg;
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	ClipboardType dataType = mimeTypeToDataType(mimeType);
	switch (dataType)
	{
		case CLIPBOARD_TEXT:
		{
			board.strings = nil;
			break;
		}
		case CLIPBOARD_URI_LIST:
		{
			board.URLs = nil;
			break;
		}
		case CLIPBOARD_IMAGE:
		{
			board.images = nil;
			break;
		}
		case CLIPBOARD_UNKNOWN:
		default:
		{
			NSData *data = [[NSData alloc] init];
			[board setData:data forPasteboardType: mimeTypeToUTType(mimeType)];
			[data release];
		}
	}
}
	 
-(void)clearText:(id)args
{
	ENSURE_UI_THREAD(clearText,args);

	UIPasteboard *board = [UIPasteboard generalPasteboard];
	board.strings = nil;
}
	 
-(id)getData:(id)args
{
    id arg = nil;
    if ([args isKindOfClass:[NSArray class]])
    {
        if ([args count] > 0)
        {
            arg = [args objectAtIndex:0];
        }
    }
    else 
    {
        arg = args;
    }
	ENSURE_STRING(arg);
	NSString *mimeType = arg;
	__block id result;
	TiThreadPerformOnMainThread(^{
		result = [[self getData_: mimeType] retain];
	}, YES);
	return [result autorelease];
}

// Must run on main thread.
-(id)getData_:(NSString *)mimeType
{
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	ClipboardType dataType = mimeTypeToDataType(mimeType);
	switch (dataType)
	{
		case CLIPBOARD_TEXT:
		{
			return board.string;
		}
		case CLIPBOARD_URI_LIST:
		{
			return [board.URL absoluteString];
		}
		case CLIPBOARD_IMAGE:
		{
			UIImage *image = board.image;
			if (image) {
				return [[[TiBlob alloc] _initWithPageContext:[self pageContext] andImage:image] autorelease];
			} else {
				return nil;
			}
		}
		case CLIPBOARD_UNKNOWN:
		default:
		{
			NSData *data = [board dataForPasteboardType: mimeTypeToUTType(mimeType)];

			if (data) {
				return [[[TiBlob alloc] _initWithPageContext:[self pageContext] andData:data mimetype:mimeType] autorelease];
			} else {
				return nil;
			}
		}
	}
}
	 
-(NSString *)getText:(id)args
{
	return [self getData: @"text/plain"];
}
	 
-(id)hasData:(id)args
{
    id arg = nil;
    if ([args isKindOfClass:[NSArray class]])
    {
        if ([args count] > 0)
        {
            arg = [args objectAtIndex:0];
        }
    }
    else 
    {
        arg = args;
    }
	ENSURE_STRING_OR_NIL(arg);
	NSString *mimeType = arg;
	__block BOOL result=NO;
	TiThreadPerformOnMainThread(^{
		UIPasteboard *board = [UIPasteboard generalPasteboard];
		ClipboardType dataType = mimeTypeToDataType(mimeType);
		
		switch (dataType)
		{
			case CLIPBOARD_TEXT:
			{
				result=[board containsPasteboardTypes: UIPasteboardTypeListString];
				break;
			}
			case CLIPBOARD_URI_LIST:
			{
				result=[board containsPasteboardTypes: UIPasteboardTypeListURL];
				break;
			}
			case CLIPBOARD_IMAGE:
			{
				result=[board containsPasteboardTypes: UIPasteboardTypeListImage];
				break;
			}
			case CLIPBOARD_UNKNOWN:
			default:
			{
				result=[board containsPasteboardTypes: [NSArray arrayWithObject: mimeTypeToUTType(mimeType)]];
				break;
			}
		}
	}, YES);
	return NUMBOOL(result);
}


	 
-(id)hasText:(id)unused
{
#if IS_XCODE_8
    if ([TiUtils isIOS10OrGreater]) {
        return NUMBOOL([[UIPasteboard generalPasteboard] hasStrings]);
    }
#endif
    
    return [self hasData: @"text/plain"];
}

-(id)hasColors:(id)unused
{
#if IS_XCODE_8
    if ([TiUtils isIOS10OrGreater]) {
        return NUMBOOL([[UIPasteboard generalPasteboard] hasColors]);
    }
#endif

    NSLog(@"[WARN] Ti.UI.Clipboard.hasColors() is only available on iOS 10 and later.");
    return NUMBOOL(NO);
}

-(id)hasImages:(id)unused
{
#if IS_XCODE_8
    if ([TiUtils isIOS10OrGreater]) {
        return NUMBOOL([[UIPasteboard generalPasteboard] hasImages]);
    }
#endif
    
    NSLog(@"[WARN] Ti.UI.Clipboard.hasImages() is only available on iOS 10 and later.");
    return NUMBOOL(NO);
}

-(id)hasURLs:(id)unused
{
#if IS_XCODE_8
    if ([TiUtils isIOS10OrGreater]) {
        return NUMBOOL([[UIPasteboard generalPasteboard] hasURLs]);
    }
#endif
    
    NSLog(@"[WARN] Ti.UI.Clipboard.hasURLs() is only available on iOS 10 and later.");
    return NUMBOOL(NO);
}

-(void)setItems:(id)args
{
#if IS_XCODE_8
    if ([TiUtils isIOS10OrGreater]) {
        NSArray *items = [args objectAtIndex:0];
        NSDictionary *options = [args objectAtIndex:1];
        
        // The option must be a UIPasteboardOption which is mapped to strings
        for (id option in options) {
            ENSURE_TYPE(option, NSString);
        }
        
        [[UIPasteboard generalPasteboard] setItems:args options:options];
    }
#endif
}

-(void)setData:(id)args
{
	ENSURE_ARG_COUNT(args,2);
	ENSURE_UI_THREAD(setData,args);
	
	NSString *mimeType = [TiUtils stringValue: [args objectAtIndex: 0]];
	id data = [args objectAtIndex: 1];
    if (data == nil) {
        DebugLog(@"[WARN] setData: data object was nil.");
        return;
    }
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	ClipboardType dataType = mimeTypeToDataType(mimeType);
	
	switch (dataType)
	{
		case CLIPBOARD_TEXT:
		{
			board.string = [TiUtils stringValue: data];
			break;
		}
		case CLIPBOARD_URI_LIST:
		{
			board.URL = [NSURL URLWithString: [TiUtils stringValue: data]];
			break;
		}
		case CLIPBOARD_IMAGE:
		{
			board.image = [TiUtils toImage: data proxy: self];
			break;
		}
		case CLIPBOARD_UNKNOWN:
		default:
		{
			NSData *raw;
			if ([data isKindOfClass:[TiBlob class]])
			{
				raw = [(TiBlob *)data data];
			}
			else if ([data isKindOfClass:[TiFile class]])
			{
				raw = [[(TiFile *)data blob] data];
			}
			else
			{
				raw = [[TiUtils stringValue: data] dataUsingEncoding: NSUTF8StringEncoding];
			}

			[board setData: raw forPasteboardType: mimeTypeToUTType(mimeType)];
		}
	}
}

-(void)setText:(id)arg
{
	ENSURE_STRING(arg);
	NSString *text = arg;
	[self setData: [NSArray arrayWithObjects: @"text/plain",text,nil]];
}
	 
 @end
