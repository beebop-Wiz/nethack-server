#define _XOPEN_SOURCE

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <libwebsockets.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <poll.h>
#include <sys/wait.h>

#include <vector>

#define MAXIMUM_UPDATE_SIZE 1024

static int destroy_flag = 0;

static void INT_HANDLER(int signo) {
  destroy_flag = 1;
}

int websocket_write_back(struct lws *wsi_in, char *str, int str_size_in)  {
  if (str == NULL || wsi_in == NULL)
    return -1;

  int n;
  int len;
  char *out = NULL;

  if (str_size_in < 1) 
    len = strlen(str);
  else
    len = str_size_in;

  out = (char *)calloc(sizeof(char), (LWS_SEND_BUFFER_PRE_PADDING + len + 1 + LWS_SEND_BUFFER_POST_PADDING));
  memcpy (out + LWS_SEND_BUFFER_PRE_PADDING, str, len);
  n = lws_write(wsi_in, (unsigned char *) out + LWS_SEND_BUFFER_PRE_PADDING, len + 1, LWS_WRITE_BINARY);

  free(out);

  return n;
}

class Connection {
public:
  Connection() {
    char *slavename;
    masterfd = open("/dev/ptmx", O_RDWR | O_NONBLOCK);
    grantpt(masterfd);
    unlockpt(masterfd);
    slavename = ptsname(masterfd);
    printf("Added client, pty %s.\n", slavename);
    printf("Starting dgamelaunch...\n");
    pid_t c;
    if(c = fork()) {
      dgl = c;
    } else {
      int fds = open(ptsname(masterfd), O_RDWR);
      close(0);
      close(1);
      close(2);
      dup(fds);
      dup(fds);
      dup(fds);
      execlp("/opt/nethack/dgamelaunch", "dgamelaunch", NULL);
    }
    printf("dgl at pid %d\n", c);
  }

  ~Connection() {
    if(dgl < 1) return;
    close(masterfd);
    kill(dgl, SIGTERM);
    waitpid(dgl, NULL, 0);
  }

  int handle_recv(struct lws *wsi, char *text, size_t len) {
    write(masterfd, text, len);
    //    printf("recv %x\n", text[0]);
    return poll_in(wsi);
  }

  int poll_in(struct lws *wsi) {
    char buf[MAXIMUM_UPDATE_SIZE];
    if(masterfd && dgl) {
      int stat;
      if(waitpid(dgl, &stat, WNOHANG)) {
	printf("proc %d dead (%d)\n", dgl, stat);
	dgl = 0;
	return -1;
      }
      struct pollfd p = {masterfd, POLLIN, 0};
      poll(&p, 1, 0);
      if(p.revents) {
	int nread;
	do {
	  bzero(buf, MAXIMUM_UPDATE_SIZE);
	  nread = read(masterfd, buf, MAXIMUM_UPDATE_SIZE);
	  websocket_write_back(wsi, buf, nread);
	} while(nread > MAXIMUM_UPDATE_SIZE);
      }
    }
    return 0;
  }

private:
  int masterfd;
  pid_t dgl;
};

std::vector<Connection *> conns;

int nfds = 3;
int nconns = 0;

static int ws_service_callback(struct lws *wsi, enum lws_callback_reasons reason, void *user, void *in, size_t len) {
  char *text;
  char buf[MAXIMUM_UPDATE_SIZE];
  char *req;
  int *uid = (int *) user;
  switch (reason) {
  case LWS_CALLBACK_ESTABLISHED:
    printf("Websocket connection established (%d connections open now).\n", ++nconns);
    if(conns.size() == 0) conns.resize(1);
    for(*uid = 1; *uid < conns.size(); *uid++) {
      if(conns[*uid] == 0) {
	conns[*uid] = new Connection();
	goto inserted;
      }
    }
    *uid = conns.size();
    conns.push_back(new Connection());
  inserted:
    printf("added connection, id %d, ptr %p (%ld total)\n", *uid, conns[*uid], conns.size());
    *((int *) user) = *uid;
    break;
  case LWS_CALLBACK_RECEIVE:
    text = (char *) in;
    if(!conns[*uid]) {
      printf("Can't handle recv for deleted uid %d\n", *uid);
      return -1;
    }
    if(conns[*uid]->handle_recv(wsi, text, len) < 0) {
      delete conns[*uid];
      conns[*uid] = 0;
      return -1;
    }
    break;
  case LWS_CALLBACK_CLOSED:
    printf("WS connection %d closed\n", *uid);
    delete conns[*uid];
    conns[*uid] = 0;
    printf("Websocket connection closed by client (%d connections open now).\n", --nconns);
    break;
  case LWS_CALLBACK_HTTP:
    printf("Got HTTP request\n");
    req = (char *) in;
    if(strcmp(req, "/") == 0) strcpy(req, "index.html");
    char cwd[1024];
    char *resource_path;
               
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
      resource_path = (char *) malloc(strlen(cwd) + strlen(req) + strlen("/htdocs/") + 1);
      
      sprintf(resource_path, "%s/htdocs/%s", cwd, req);
      printf("resource path: %s\n", resource_path);
      
      char *extension = strrchr(resource_path, '.');
      char *mime;
                   
      if (extension == NULL) {
	mime = strdup("text/plain");
      } else if (strcmp(extension, ".png") == 0) {
	mime = strdup("image/png");
      } else if (strcmp(extension, ".js") == 0) {
	mime = strdup("text/javascript");
      } else if (strcmp(extension, ".html") == 0) {
	mime = strdup("text/html");
      } else if (strcmp(extension, ".css") == 0) {
	mime = strdup("text/css");
      } else {
	mime = strdup("text/plain");
      }
      if(!strcmp(req, "/leaderboard")) {
	char tmp1buf[] = "/tmp/wscgi.XXXXXX";
	int tmp1fd = mkstemp(tmp1buf);
	char tmp2buf[] = "/tmp/wsarg.XXXXXX";
	int tmp2fd = mkstemp(tmp2buf);
	int n = 0;
	while(lws_hdr_copy_fragment(wsi, buf, sizeof(buf), WSI_TOKEN_HTTP_URI_ARGS, n++) > 0) {
	  write(tmp2fd, buf, strlen(buf));
	  write(tmp2fd, "\n", 1);
	}
	lseek(tmp2fd, 0, SEEK_SET);
	pid_t perl;
	if(perl = fork()) {
	  waitpid(perl, NULL, 0);
	  lws_serve_http_file(wsi, tmp1buf, "text/html", NULL, 0);
	  unlink(tmp1buf);
	  unlink(tmp2buf);
	} else {
	  close(0);
	  close(1);
	  close(2);
	  dup(tmp2fd);
	  dup(tmp1fd);
	  dup(tmp1fd);
	  execlp("/usr/bin/perl", "perl", "pgleaderboard.pl", NULL);
	}
      } else {
	  lws_serve_http_file(wsi, resource_path, mime, NULL, 0);
      }
      free(mime);
      printf("HTTP serve complete\n");
    }
    return -1;
  case LWS_CALLBACK_USER:
    if(uid
       && conns.size() > *uid
       && conns[*uid])
      if(conns[*uid]->poll_in(wsi) < 0) {
	delete conns[*uid];
	conns[*uid] = 0;
	return -1;
      }
    break;
  default:
    break;
  }
  return 0;
}

int main(void) {
  srand(time(NULL));
  int port = 8080;
  const char *interface = NULL;
  struct lws_context_creation_info info;
  struct lws_protocols protocol;
  struct lws_context *context;
  const char *cert_path = NULL;
  const char *key_path = NULL;
  int opts = 0;

  struct sigaction act;
  act.sa_handler = INT_HANDLER;
  act.sa_flags = 0;
  sigemptyset(&act.sa_mask);
  sigaction( SIGINT, &act, 0);

  protocol.name = "nethack";
  protocol.callback = ws_service_callback;
  protocol.per_session_data_size = sizeof(int);
  protocol.rx_buffer_size = 131072;

  memset(&info, 0, sizeof info);
  info.port = port;
  info.iface = interface;
  info.protocols = &protocol;
  //  info.extensions = lws_get_internal_extensions();
  info.ssl_cert_filepath = cert_path;
  info.ssl_private_key_filepath = key_path;
  info.gid = -1;
  info.uid = -1;
  info.options = opts;

  context = lws_create_context(&info);
  if(context == NULL) {
    printf("Couldn't init websockets!\n");
    return -1;
  }

  while(!destroy_flag) {
    lws_service(context, 50);
    lws_callback_all_protocol(context, &protocol, LWS_CALLBACK_USER);
  }
  int i;
  for(i = 0; i < 100000; i++) ;
  lws_context_destroy(context);

  return 0;
}
