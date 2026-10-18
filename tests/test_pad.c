#include "internal.h"
#include <assert.h>
#include <stdio.h>
typedef struct { int sends, leds, capture, fail; uint64_t device; uint8_t bytes[2][11]; } Fake;
static int info(void *u,bbm_pad_info *p){Fake*f=u;memset(p,0,sizeof *p);p->device_id=f->device;p->kind=BBM_PAD_DUALSENSE;p->features=f->device?3:0;return 0;}
static int send(void*u,const uint8_t*r,const uint8_t*l){Fake*f=u;f->sends++;if(f->fail)return -1;memcpy(f->bytes[0],l,11);memcpy(f->bytes[1],r,11);return 0;}
static int led(void*u,uint8_t r,uint8_t g,uint8_t b){(void)r;(void)g;(void)b;((Fake*)u)->leds++;return 0;}
static int cap(void*u){return ((Fake*)u)->capture;}
int main(void){
 Fake f={.device=1};modhost_config cfg={0};cfg.cache_dir="pad-test-cache";
 cfg.pad=(modhost_pad_backend){&f,info,send,led,cap};modhost*h=modhost_create(&cfg);assert(h);
 struct bbm_mod a={.host=h},b={.host=h};uint8_t e[11]={1,20,30},other[11]={1,20,90};
 assert(h->api.pad_trigger(&a,2,e)==BBM_ERR_ARG);
 assert(h->api.pad_trigger(&a,1,e)==0);assert(h->api.pad_trigger(&b,1,e)==BBM_ERR_CONFLICT);
 mh_pad_tick(h,100);assert(f.sends==1&&f.bytes[1][2]==30);
 mh_pad_tick(h,110);assert(f.sends==1);
 assert(h->api.pad_trigger(&a,1,other)==0);mh_pad_tick(h,133);assert(f.sends==1);
 mh_pad_tick(h,134);assert(f.sends==2&&f.bytes[1][2]==90);
 f.capture=1;mh_pad_tick(h,135);assert(f.sends==3&&f.bytes[1][0]==5);
 f.capture=0;mh_pad_tick(h,169);assert(f.sends==4&&f.bytes[1][2]==90);
 f.device=0;mh_pad_tick(h,200);assert(h->api.pad_trigger(&a,1,e)==BBM_ERR_UNSUPPORTED);
 f.device=2;mh_pad_tick(h,201);assert(f.sends==5&&f.bytes[1][2]==90);
 f.fail=1;h->api.pad_trigger(&a,1,e);mh_pad_tick(h,235);assert(f.sends==6);
 mh_pad_tick(h,1234);assert(f.sends==6);f.fail=0;mh_pad_tick(h,1235);assert(f.sends==7);
 assert(h->api.pad_release(&b,1)==BBM_ERR_CONFLICT);
 assert(h->api.pad_release(&a,1)==0);assert(f.bytes[1][0]==5);
 assert(h->api.pad_trigger(&b,1,e)==0);h->pad_next_ms=0;mh_pad_tick(h,2000);
 mh_res_release_all(&b);assert(!h->trigger_owner[1]&&f.bytes[1][0]==5);
 assert(h->api.pad_lightbar(&a,120,0,10)==0);assert(h->api.pad_lightbar(&b,0,0,0)==BBM_ERR_CONFLICT);
 a.faulted=1;assert(h->api.pad_trigger(&a,0,e)==BBM_ERR_STATE);
 mh_res_release_all(&a);assert(!h->led_owner);
 modhost_destroy(h);puts("pad ownership, coalescing, capture, reconnect, retry, cleanup: OK");return 0;
}
