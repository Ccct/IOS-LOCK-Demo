//
//  ViewController.m
//  LockDemo
//
//  Created by Helios on 2019/5/11.
//  Copyright © 2019 Helios. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <libkern/OSSpinLockDeprecated.h>

static pthread_mutex_t theLock;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /// 互斥锁
//    [self lock_Method];
//    [self pthread_mutex_Method];
//    [self threadMethond3];
//    [self threadMethond4];
    [self NSRecursiveLockAction];
}

#pragma mark -  1、互斥锁 - NSLock
/**
 一个线程在加锁的时候，其余请求锁的线程将形成一个等待队列，按先进先出原则
 */
-(void)lock_Method{
    
    NSLock *lock = [[NSLock alloc] init];
    
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [lock lock];
        NSLog(@"线程1");
        sleep(5);
        [lock unlock];
        NSLog(@"线程1解锁成功");
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [lock lock];
        NSLog(@"线程2");
        [lock unlock];
    });
}

#pragma mark - 2、互斥锁 - pthread_mutex
/**
 是 C 语言下多线程加互斥锁的方式,被这个锁保护的临界区就只允许一个线程进入，其它线程如果没有获得锁权限，那就只能在外面等着。
 */
-(void)pthread_mutex_Method{
    
    /*
    PTHREAD_MUTEX_NORMAL     缺省类型，也就是普通锁。当一个线程加锁以后，其余请求锁的线程将形成一个等待队列，并在解锁后先进先出原则获得锁。
    
    PTHREAD_MUTEX_ERRORCHECK 检错锁，如果同一个线程请求同一个锁，则返回 EDEADLK，否则与普通锁类型动作相同。这样就保证当不允许多次加锁时不会出现嵌套情况下的死锁。
    
    PTHREAD_MUTEX_RECURSIVE  递归锁，允许同一个线程对同一个锁成功获得多次，并通过多次 unlock 解锁。
    
    PTHREAD_MUTEX_DEFAULT    适应锁，动作最简单的锁类型，仅等待解锁后重新竞争，没有等待队列。
    */
    pthread_mutex_init(&theLock, PTHREAD_MUTEX_NORMAL);
    
    pthread_t thread;
    pthread_create(&thread, NULL, threadMethond1, NULL);
    
    pthread_t thread2;
    pthread_create(&thread2,NULL,threadMethond2, NULL);
}

void *threadMethond1(){
    
    pthread_mutex_lock(&theLock);
    printf("线程1\n");
    sleep(5);
    
    pthread_mutex_unlock(&theLock);
    printf("线程1解锁成功\n");
    return 0;
}

void *threadMethond2(){
    
    pthread_mutex_lock(&theLock);
    printf("线程2\n");
    pthread_mutex_unlock(&theLock);
    return 0;
}

/*
 互斥锁不是万能灵药
 
 基本上所有的问题都可以用互斥的方案去解决，大不了就是慢点儿，但不要不管什么情况都用互斥，都能采用这种方案不代表都适合采用这种方案。
 而且这里所说的慢不是说mutex的实现方案比较慢，而是互斥方案影响的面比较大，本来不需要通过互斥就能让线程进入临界区，但用了互斥方案之后，就使这样的线程不得不等待互斥锁的释放，所以就慢了。
 甚至有些场合用互斥就很蛋疼，比如多资源分配，线程步调通知等。 如果是读多写少的场合，就比较适合读写锁，如果临界区比较短，就适合空转锁。

 */



/*预防死锁

1、如果要进入一段临界区需要多个mutex锁，那么就很容易导致死锁，单个mutex锁是不会引发死锁的。

要解决这个问题也很简单，只要申请锁的时候按照固定顺序，或者及时释放不需要的mutex锁就可以，尤其是全局mutex锁的时候，更需要遵守一个约定。
我的mutex锁的命名规则就是：


作用_mutex_序号，比如LinkListMutex_mutex_1,OperationQueue_mutex_2，后面的序号在每次有新锁的时候，就都加一个1。如果有哪个临界区进入的时候需要获得多个mutex锁的，我就按照序号的顺序去进行加锁操作，这样就能够保证不会出现死锁了。
如果是属于某个struct内部的mutex锁，也一样，只不过序号可以不必跟全局锁挂钩，也可以从1开始数。
 
 2、还有另一种方案也非常有效，就是用pthread_mutex_trylock函数来申请加锁，这个函数在mutex锁不可用时，不像pthread_mutex_lock那样会等待。pthread_mutex_trylock在申请加锁失败时立刻就会返回错误:EBUSY(锁尚未解除)或者EINVAL(锁变量不可用)。
 
 一旦在trylock的时候有错误返回，那就把前面已经拿到的锁全部释放，然后过一段时间再来一遍。
 当然也可以使用pthread_mutex_timedlock这个函数来申请加锁，这个函数跟pthread_mutex_trylock类似，不同的是，你可以传入一个时间参数，在申请加锁失败之后会阻塞一段时间等解锁，超时之后才返回错误。
 
 
 这两种方案我更多会使用第一种，原因如下：
 
 一般情况下进入临界区需要加的锁数量不会太多，第一种方案能够hold住。如果多于2个，你就要考虑一下是否有些锁是可以合并的了。第一种方案适合锁比较少的情况，因为这不会导致非常大的阻塞延时。但是当你要加的锁非常多，A、B、C、D、E，你加到D的时候阻塞了，然而其他线程可能只需要A、B就可以运行，就也会因为A、B已经被锁住而阻塞，这时候才会采用第二种方案。如果要加的锁本身就不多，只有A、B两个，那么阻塞一下也还可以。
 第二种方案在面临阻塞的时候，要操作的事情太多。当你把所有的锁都释放以后，你的当前线程的处理策略就会导致你的代码复杂度上升：当前线程总不能就此退出吧，你得找个地方把它放起来，让它去等待一段时间之后再去申请锁，如果有多个线程出现了这样的情况，你就需要一个线程池来存放这些等待解锁的线程。如果临界区是嵌套的，你在把这个线程挂起的时候，最好还要把外面的锁也释放掉，要不然也会容易导致死锁，这就需要你在一个地方记录当前线程使用锁的情况。这里要做的事情太多，复杂度比较大，容易出错。
 
 
 所以总而言之，设计的时候尽量减少同一临界区所需要mutex锁的数量，然后采用第一种方案。如果确实有需求导致那么多mutex锁，那么就只能采用第二种方案了，然后老老实实写好周边代码。

*/

#pragma mark - 3、互斥锁 - 递归锁-pthread_mutex(recursive)
-(void)threadMethond3{
    
    pthread_mutex_init(&theLock, NULL);
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    
    pthread_mutex_init(&theLock, &attr);
    pthread_mutexattr_destroy(&attr);
    
    pthread_t thread;
    pthread_create(&thread, NULL, pthread_mutex_threadMethord, 5);
}

void *pthread_mutex_threadMethord(int value) {
    
    pthread_mutex_lock(&theLock);
    
    if (value > 0) {
        printf("Value:%i\n", value);
        sleep(1);
        pthread_mutex_threadMethord(value - 1);
    }
    pthread_mutex_unlock(&theLock);
    return 0;
}

#pragma mark - 4、互斥锁 - @synchronized
/*
 @synchronized(object) 指令使用的 object 为该锁的唯一标识，只有当标识相同时，才满足互斥，所以如果线程 2 中的 @synchronized(self) 改为@synchronized(self.view)，则线程2就不会被阻塞
 
 @synchronized 指令实现锁的优点就是我们不需要在代码中显式的创建锁对象，便可以实现锁的机制，但作为一种预防措施，@synchronized 块会隐式的添加一个异常处理例程来保护代码，该处理例程会在异常抛出的时候自动的释放互斥锁。
 如果在 @sychronized(object){} 内部 object 被释放或被设为 nil，从测试的结果来看，的确没有问题，但如果 object 一开始就是 nil，则失去了锁的功能。但 @synchronized([NSNull null]) 是完全可以的。
 */
-(void)threadMethond4{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self) {
            
            NSLog(@"线程1");
            sleep(3);
        }
        sleep(3);
        NSLog(@"线程1解锁成功");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self) {
            NSLog(@"线程2");
        }
    });
}

#pragma mark - 5、自旋锁 - OSSpinLock
/*
 OSSpinLock 是一种自旋锁，也只有加锁，解锁，尝试加锁三个方法。
 和 NSLock 不同的是 NSLock 请求加锁失败的话，会先轮询，但一秒过后便会使线程进入 waiting 状态，等待唤醒。
 而 OSSpinLock 会一直轮询，等待时会消耗大量 CPU 资源，不适用于较长时间的任务。
 
 10.0弃用，使用os_unfair_lock
 */
-(void)OSSpinLockAction{
    
    __block OSSpinLock theLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //加锁
        OSSpinLockLock(&theLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        //解锁
        OSSpinLockUnlock(&theLock);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //加锁
        OSSpinLockLock(&theLock);
        sleep(1);
        NSLog(@"需要线程同步的操作2");
        //解锁
        OSSpinLockUnlock(&theLock);
    });
}

/*
 os_unfair_lock 是苹果官方推荐的替换OSSpinLock的方案，但是它在iOS10.0以上的系统才可以调用。
 */

#pragma mark - 6、读写锁 - pthread_rwlock

/*
 前面互斥锁mutex有个缺点，就是只要锁住了，不管其他线程要干什么，都不允许进入临界区。
 
 设想这样一种情况：临界区foo变量在被bar1线程读着，加了个mutex锁，bar2线程如果也要读foo变量，因为被bar1加了个互斥锁，那就不能读了。
 但事实情况是，读取数据不影响数据内容本身，所以即便被1个线程读着，另外一个线程也应该允许他去读。除非另外一个线程是写操作，为了避免数据不一致的问题，写线程就需要等读线程都结束了再写。
 
 
 因此诞生了读写锁，有的地方也叫共享锁。
 
 读写锁的特性是这样的
 
 当一个线程加了读锁访问临界区，另外一个线程也想访问临界区读取数据的时候，也可以加一个读锁，这样另外一个线程就能够成功进入临界区进行读操作了。此时读锁线程有两个。
 当第三个线程需要进行写操作时，它需要加一个写锁，这个写锁只有在读锁的拥有者为0时才有效。也就是等前两个读线程都释放读锁之后，第三个线程就能进去写了。
 
 
 总结一下就是，读写锁里，读锁能允许多个线程同时去读，但是写锁在同一时刻只允许一个线程去写。
 
 这样更精细的控制，就能减少mutex导致的阻塞延迟时间。虽然用mutex也能起作用，但这种场合，明显读写锁更好！
 
 PTHREAD_RWLOCK_INITIALIZER
 
 int pthread_rwlock_init(pthread_rwlock_t *restrict rwlock, const pthread_rwlockattr_t *restrict attr);
 int pthread_rwlock_destroy(pthread_rwlock_t *rwlock);
 
 //加读锁
 int pthread_rwlock_rdlock(pthread_rwlock_t *rwlock);
 int pthread_rwlock_tryrdlock(pthread_rwlock_t *rwlock);
 
 //加写锁
 int pthread_rwlock_wrlock(pthread_rwlock_t *rwlock);
 int pthread_rwlock_trywrlock(pthread_rwlock_t *rwlock);
 
 //解锁
 int pthread_rwlock_unlock(pthread_rwlock_t *rwlock);
 
 // 这个函数在Linux和Mac的man文档里都没有，新版的pthread.h里面也没有，旧版的能找到
 int pthread_rwlock_timedrdlock_np(pthread_rwlock_t *rwlock, const struct timespec *deltatime);
 // 同上
 int pthread_rwlock_timedwrlock_np(pthread_rwlock_t *rwlock, const struct timespec *deltatime);
 
 注意的地方
 
 命名
 
 跟上面提到的写muetx互斥锁的约定一样，操作，类别，序号最好都要有。比如OperationQueue_rwlock_1。
 
 
 认真区分使用场合
 
 由于读写锁的性质，在默认情况下是很容易出现写线程饥饿的。因为它必须要等到所有读锁都释放之后，才能成功申请写锁。不过不同系统的实现版本对写线程的优先级实现不同。Solaris下面就是写线程优先，其他系统默认读线程优先。
 比如在写线程阻塞的时候，有很多读线程是可以一个接一个地在那儿插队的(在默认情况下，只要有读锁在，写锁就无法申请，然而读锁可以一直申请成功，就导致所谓的插队现象)，那么写线程就不知道什么时候才能申请成功写锁了，然后它就饿死了。
 为了控制写线程饥饿，必须要在创建读写锁的时候设置PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE，不要用PTHREAD_RWLOCK_PREFER_WRITER_NP，这个似乎没什么用，感觉应该是个bug
 
 ////////////////////////////// /usr/include/pthread.h
 */

/*#if defined __USE_UNIX98 || defined __USE_XOPEN2K
enum
{
    PTHREAD_RWLOCK_PREFER_READER_NP,
    PTHREAD_RWLOCK_PREFER_WRITER_NP, // 妈蛋，没用，一样reader优先
    PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP,
    PTHREAD_RWLOCK_DEFAULT_NP = PTHREAD_RWLOCK_PREFER_READER_NP
};


总的来说，这样的锁建立之后一定要设置优先级，不然就容易出现写线程饥饿。而且读写锁适合读多写少的情况，如果读、写一样多，那这时候还是用mutex互斥锁比较合理。

 */

#pragma mark - 7、递归锁 - NSRecursiveLock

/*
 递归锁有一个特点，就是同一个线程可以加锁N次而不会引发死锁。
 
 他和 NSLock 的区别在于，NSRecursiveLock 可以在一个线程中重复加锁（反正单线程内任务是按顺序执行的，不会出现资源竞争问题），NSRecursiveLock 会记录上锁和解锁的次数，当二者平衡的时候，才会释放锁，其它线程才可以上锁成功。
 */

-(void)NSRecursiveLockAction{
    
    NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            [lock lock];
            if (value > 0) {
                NSLog(@"value:%d", value);
                RecursiveBlock(value - 1);
            }
            [lock unlock];
        };
        RecursiveBlock(3);
    });
}
/*
 如上面的示例，如果用 NSLock 的话，lock 先锁上了，但未执行解锁的时候，就会进入递归的下一层，而再次请求上锁，阻塞了该线程，线程被阻塞了，自然后面的解锁代码不会执行，而形成了死锁。而 NSRecursiveLock 递归锁就是为了解决这个问题。主要是用在循环或递归操作中。
 这段代码是一个典型的死锁情况。在我们的线程中，RecursiveMethod是递归调用的。所以每次进入这个block时，都会去加一次锁，而从第二次开始，由于锁已经被使用了且没有解锁，所以它需要等待锁被解除，这样就导致了死锁，线程被阻塞住了。
 */

#pragma mark - 8、递归锁 - pthread_mutex(recursive)

/*见上文*/

#pragma mark - 9、条件锁 - NSCondition
/*
 一种最基本的条件锁。手动控制线程wait和signal。
 遵循NSLocking协议，使用的时候同样是lock,unlock加解锁，wait是傻等，waitUntilDate:方法是等一会，都会阻塞掉线程，signal是唤起一个在等待的线程，broadcast是广播全部唤起。
 
 NSCondition 的对象实际上作为一个锁和一个线程检查器，锁上之后其它线程也能上锁，而之后可以根据条件决定是否继续运行线程，即线程是否要进入 waiting 状态，经测试，NSCondition 并不会像上文的那些锁一样，先轮询，而是直接进入 waiting 状态，当其它线程中的该锁执行 signal 或者 broadcast 方法时，线程被唤醒，继续运行之后的方法。

 */
-(void)NSConditionAction{
    
    NSCondition *lock = [[NSCondition alloc] init];
    NSMutableArray *array = [[NSMutableArray alloc] init];
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lock];
        while (!array.count) {
            [lock wait];
        }
        [array removeAllObjects];
        NSLog(@"array removeAllObjects");
        [lock unlock];
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);//以保证让线程2的代码后执行
        [lock lock];
        [array addObject:@1];
        NSLog(@"array addObject:@1");
        [lock signal];
        [lock unlock];
    });
}

#pragma mark - 10、条件锁 - NSConditionLock
/*
 NSConditionLock 和 NSLock 类似，都遵循 NSLocking 协议，方法都类似，只是多了一个 condition 属性，以及每个操作都多了一个关于 condition 属性的方法，只有 condition 参数与初始化时候的 condition 相等，lock 才能正确进行加锁操作。而 unlockWithCondition: 并不是当 Condition 符合条件时才解锁，而是解锁之后，修改 Condition 的值，这个结论可以从下面的例子中得出。
 */
-(void)NSConditionLockAction{
    
    //主线程中
    NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
    
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lockWhenCondition:1];
        NSLog(@"线程1");
        sleep(2);
        [lock unlock];
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);//以保证让线程2的代码后执行
        if ([lock tryLockWhenCondition:0]) {
            NSLog(@"线程2");
            [lock unlockWithCondition:2];
            NSLog(@"线程2解锁成功");
        } else {
            NSLog(@"线程2尝试加锁失败");
        }
    });
    
    //线程3
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);//以保证让线程2的代码后执行
        if ([lock tryLockWhenCondition:2]) {
            NSLog(@"线程3");
            [lock unlock];
            NSLog(@"线程3解锁成功");
        } else {
            NSLog(@"线程3尝试加锁失败");
        }
    });
    
    //线程4
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(3);//以保证让线程2的代码后执行
        if ([lock tryLockWhenCondition:2]) {
            NSLog(@"线程4");
            [lock unlockWithCondition:1];
            NSLog(@"线程4解锁成功");
        } else {
            NSLog(@"线程4尝试加锁失败");
        }
    });
}
/*
 从上面可以得出，NSConditionLock 还可以实现任务之间的依赖。
 */

#pragma mark - 11、信号量 dispatch_semaphore
/*
 dispatch_semaphore 是 GCD 用来同步的一种方式，与他相关的只有三个函数，一个是创建信号量，一个是等待信号，一个是发送信号。
 这个函数的作用是这样的
 
 如果dsema信号量的值大于0，该函数所处线程就继续执行下面的语句，并且将信号量的值减1；
 如果desema的值为0，那么这个函数就阻塞当前线程等待timeout（注意timeout的类型为dispatch_time_t，不能直接传入整形或float型数）
 如果等待的期间desema的值被dispatch_semaphore_signal函数加1了，且该函数（即dispatch_semaphore_wait）所处线程获得了信号量，那么就继续向下执行并将信号量减1。
 如果等待期间没有获取到信号量或者信号量的值一直为0，那么等到timeout时，其所处线程自动执行其后语句。
 
 
 dispatch_semaphore 是信号量，但当信号总量设为 1 时也可以当作锁来。在没有等待情况出现时，它的性能比 pthread_mutex 还要高，但一旦有等待情况出现时，性能就会下降许多。相对于 OSSpinLock 来说，它的优势在于等待时不会消耗 CPU 资源。
 
 */
-(void)dispatch_semaphoreAction{
    
    // 超时时间overTime设置成>2
    dispatch_semaphore_t signal = dispatch_semaphore_create(1);
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(2);
        NSLog(@"需要线程同步的操作1 结束");
        dispatch_semaphore_signal(signal);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"需要线程同步的操作2");
        dispatch_semaphore_signal(signal);
    });
    // 需要线程同步的操作1 开始
    // 需要线程同步的操作1 结束
    // 需要线程同步的操作2
    
    // 超时时间设置为<2s的时候
    //...
//    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
    //...
    // 需要线程同步的操作1 开始
    // 需要线程同步的操作2
    // 需要线程同步的操作1 结束
}

/*
 如上的代码，如果超时时间overTime设置成>2，可完成同步操作。如果overTime<2的话，在线程1还没有执行完成的情况下，此时超时了，将自动执行下面的代码。
 
 
 
 
 dispatch_semaphore 和 NSCondition 类似，都是一种基于信号的同步方式，但 NSCondition 信号只能发送，不能保存（如果没有线程在等待，则发送的信号会失效）。而 dispatch_semaphore 能保存发送的信号。dispatch_semaphore 的核心是 dispatch_semaphore_t 类型的信号量。
 
 
 
 
 dispatch_semaphore_create(1) 方法可以创建一个 dispatch_semaphore_t 类型的信号量，设定信号量的初始值为 1。注意，这里的传入的参数必须大于或等于 0，否则 dispatch_semaphore_create 会返回 NULL。
 
 dispatch_semaphore_wait(signal, overTime);方法会判断 signal 的信号值是否大于 0。大于 0 不会阻塞线程，消耗掉一个信号，执行后续任务。
 
 如果信号值为 0，该线程会和 NSCondition 一样直接进入 waiting 状态，等待其他线程发送信号唤醒线程去执行后续任务，或者当 overTime  时限到了，也会执行后续任务。
 
 
 
 dispatch_semaphore_signal(signal); 发送信号，如果没有等待的线程接受信号，则使 signal 信号值加1（做到对信号的保存）。
 和 NSLock 的 lock 和 unlock类似，区别只在于有信号量这个参数，lock unlock 只能同一时间，一个线程访问被保护的临界区，而如果 dispatch_semaphore 的信号量初始值为 x ，则可以有 x 个线程同时访问被保护的临界区。
 */


/*
 
 补充
 
 pthread_cleanup_push() & pthread_cleanup_pop()
 
 
 线程是允许在退出的时候，调用一些回调方法的。如果你需要做类似的事情，那么就用以下这两种方法:
 
 void pthread_cleanup_push(void (*callback)(void *), void *arg);
 void pthread_cleanup_pop(int execute);
 
 
 正如名字所暗示的，它背后有一个stack，你可以塞很多个callback函数进去，然后调用的时候按照先入后出的顺序调用这些callback。所以你在塞callback的时候，如果是关心调用顺序的，那就得注意这一点了。
 但是！你塞进去的callback只有在以下情况下才会被调用：
 
 线程通过pthread_exit()函数退出
 线程被pthread_cancel()取消
 
 pthread_cleanup_pop(int execute)时，execute传了一个非0值
 
 
 也就是说，如果你的线程函数是这么写的，那在线程结束的时候就不会调到你塞进去的那些callback了：
 
 static void * thread_function(void *args)
 {
 ...
 ...
 ...
 ...
 return 0; // 线程退出时没有调用pthread_exit()退出，而是直接return，此时是不会调用栈内callback的
 }
 */
 
 /*
 pthread_cleanup_push塞入的callback可以用来记录线程结束的点，般不太会在这里执行业务逻辑。在线程结束之后如果要执行业务逻辑，一般用下面提到的pthread_join。
 
 注意事项：callback函数是可以传参数的
 
 在pthread_cleanup_push函数中，第二个参数的值会作为callback函数的第一个参数，拿来打打日志也不错
 
 void callback(void *callback_arg)
 {
 printf("arg is : %s\n", (char *)callback_arg);
 }
 
 static void * thread_function(void *thread_arg)
 {
 ...
 pthread_cleanup_push(callback, "this is a queue thread, and was terminated.");
 ...
 pthread_exit((void *) 0); // 这句不调用，线程结束就不会调用你塞进去的callback函数。
 return ((void *) 0);
 }
 
 int main ()
 {
 ...
 ...
 error = pthread_create(&tid, NULL, thread_function, (void *)thread_arg)
 ...
 ...
 return 0;
 }
 */
 
 /*
 要保持callback栈平衡
 pthread_cleanup_pop(0); // 传递参数0，在pop的时候就不会调用对应的callback，如果传递非0值，pop的时候就会调用对应callback了。
 pthread_cleanup_pop(0); // push了两次就pop两次,你要是只pop一次就不能编译通过
 */
 
 /*
 pthread对于这两个函数是通过宏来实现的，如果没有一一对应，编译器就会报} missing的错误。其相关实现代码如下：
 
#define pthread_cleanup_push(rt, rtarg) __pthread_cleanup_push(rt, rtarg)
#define pthread_cleanup_pop(execute) __pthread_cleanup_pop(execute)

// ./sysdeps/generic/bits/cancelation.h
#define __pthread_cleanup_push(rt, rtarg) \
{ \
struct __pthread_cancelation_handler **__handlers \
= __pthread_get_cleanup_stack (); \
struct __pthread_cancelation_handler __handler = \
{ \
(rt), \
(rtarg), \
*__handlers \
}; \
*__handlers = &__handler;

#define __pthread_cleanup_pop(execute) \
if (execute) \
__handler.handler (__handler.arg); \
*__handlers = __handler.next; \
} \

 */

@end
