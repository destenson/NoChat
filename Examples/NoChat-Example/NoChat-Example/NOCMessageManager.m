//
//  NOCMessageManager.m
//  NoChat-Example
//
//  Created by little2s on 2017/1/25.
//  Copyright © 2017年 little2s. All rights reserved.
//

#import "NOCMessageManager.h"

#import "NOCUser.h"
#import "NOCChat.h"
#import "NOCMessage.h"

#import <NOCProtoKit/NOCProtoKit.h>

@interface NOCMessageManager () <NOCClientDelegate>

@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong) NOCClient *client;

@property (nonatomic, strong) NSMutableDictionary *messages;

@end

@implementation NOCMessageManager

+ (instancetype)manager
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] _init];
    });
    return instance;
}

- (instancetype)_init
{
    self = [super init];
    if (self) {
        _delegates = [NSHashTable weakObjectsHashTable];
        _client = [[NOCClient alloc] initWithUserId:[NOCUser currentUser].userId];
        _client.delegate = self;
        _messages = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)play
{
    [self.client open];
}

- (void)fetchMessagesWithChatId:(NSString *)chatId handler:(void (^)(NSArray *messages))handler
{
    NSArray *msgs = self.messages[chatId];
    if (msgs.count) {
        handler(msgs);
    }
}

- (void)sendMessage:(NOCMessage *)message toChat:(NOCChat *)chat
{
    NSString *chatId = chat.chatId;
    [self saveMessage:message chatId:chatId];
    
    NSDictionary *dict = @{
        @"from": message.senderId,
        @"to": chat.targetId,
        @"type": message.type,
        @"text": message.text,
        @"ctype": chat.type
    };
    
    [self.client sendMessage:dict];
}

- (void)addDelegate:(id<NOCMessageManagerDelegate>)delegate
{
    if (delegate) {
        [self.delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<NOCMessageManagerDelegate>)delegate
{
    if (delegate) {
        [self.delegates removeObject:delegate];
    }
}

- (void)clientDidReceiveMessage:(NSDictionary *)message
{
    NSString *senderId = message[@"from"];
    NSString *type = message[@"type"];
    NSString *text = message[@"text"];
    NSString *chatType = message[@"ctype"];
    
    if (![type isEqualToString:@"Text"] || ![chatType isEqualToString:@"bot"]) {
        return;
    }
    
    NOCMessage *msg = [[NOCMessage alloc] init];
    msg.senderId = senderId;
    msg.type = type;
    msg.text = text;
    msg.outgoing = NO;
    msg.date = [NSDate date];
    
    NSString *chatId = [NSString stringWithFormat:@"%@_%@", chatType, senderId];
    
    [self saveMessage:msg chatId:chatId];
    
    for (id<NOCMessageManagerDelegate> delegate in self.delegates.allObjects) {
        if ([delegate respondsToSelector:@selector(didReceiveMessages:chatId:)]) {
            [delegate didReceiveMessages:@[msg] chatId:chatId];
        }
    }
}

- (void)saveMessage:(NOCMessage *)msg chatId:(NSString *)chatId
{
    NSMutableArray *msgs = self.messages[chatId];
    if (!msgs) {
        msgs = [[NSMutableArray alloc] init];
        self.messages[chatId] = msgs;
    }
    [msgs addObject:msg];
}

@end
