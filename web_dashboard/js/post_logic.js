/* POST INTERACTIVITY LOGIC */

window.togglePostMenu = function(id) {
  const menu = document.getElementById('post-menu-' + id);
  if (menu) {
    menu.classList.toggle('show');
  }
};

// Close dropdown when clicking outside
document.addEventListener('click', function(e) {
  if (!e.target.closest('.fb-post-dropdown-container')) {
    document.querySelectorAll('.fb-post-dropdown-menu.show').forEach(m => m.classList.remove('show'));
  }
});

function getProfileUserId() {
  const urlParams = new URLSearchParams(window.location.search);
  return urlParams.get('userId') || urlParams.get('id') || (localStorage.getItem('nudgeActiveDemoUserId') || 'an_nudge');
}

function getActiveUserName() {
  return localStorage.getItem('nudgeActiveDemoUserName') || '訪客';
}

function requireOwnProfileId() {
  const profileId = getProfileUserId();
  const activeUserId =
    typeof firebase !== 'undefined' && firebase.auth
      ? firebase.auth().currentUser?.uid
      : null;
  if (!activeUserId || profileId !== activeUserId) {
    toast('私人動態目前只能由本人操作；好友互動不會寫入對方的私人帳號。');
    return null;
  }
  return profileId;
}

window.editPost = function(id, isWelcome, isCustom) {
  window.togglePostMenu(id);
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  
  // Custom Modal for editing
  let modal = document.getElementById('editPostModal');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'editPostModal';
    modal.className = 'post-modal-overlay';
    modal.innerHTML = `<div class="post-modal-box"><div class="post-modal-title">修改貼文</div><textarea id="editPostTextarea" class="post-modal-textarea" placeholder="想說些什麼..."></textarea><div class="post-modal-actions"><button class="post-modal-btn cancel" onclick="closeEditModal()">取消</button><button class="post-modal-btn submit" id="editPostSubmitBtn">儲存</button></div></div>`;
    document.body.appendChild(modal);
    
    window.closeEditModal = function() {
      document.getElementById('editPostModal').classList.remove('show');
    };
  }
  
  // Find current text
  const contentEl = document.getElementById('post-content-' + id);
  const currentText = contentEl ? contentEl.innerText : '';
  const textarea = document.getElementById('editPostTextarea');
  textarea.value = currentText;
  
  const submitBtn = document.getElementById('editPostSubmitBtn');
  submitBtn.onclick = async function() {
    const newText = textarea.value.trim();
    if (!newText) { toast('內容不能為空'); return; }
    
    submitBtn.textContent = '儲存中...';
    try {
      const dbRef = db.collection('users').doc(profileId);
      if (isWelcome) {
        await dbRef.set({ welcomePost: { customText: newText } }, { merge: true });
      } else if (isCustom) {
        const doc = await dbRef.get();
        if (doc.exists) {
          const data = doc.data();
          const customPosts = data.customPosts || [];
          const idx = customPosts.findIndex(s => s.id === id);
          if (idx !== -1) {
            customPosts[idx].content = newText;
            await dbRef.update({ customPosts: customPosts });
          }
        }
      } else {
        const doc = await dbRef.get();
        if (doc.exists) {
          const data = doc.data();
          const summaries = data.dailySummaries || [];
          const idx = summaries.findIndex(s => s.date === id);
          if (idx !== -1) {
            summaries[idx].customText = newText;
            await dbRef.update({ dailySummaries: summaries });
          }
        }
      }
      toast('貼文已更新！');
      window.closeEditModal();
      window.location.reload();
    } catch (e) {
      console.error(e);
      toast('更新失敗');
    }
    submitBtn.textContent = '儲存';
  };
  
  modal.classList.add('show');
};

window.deletePost = async function(id, isWelcome, isCustom) {
  window.togglePostMenu(id);
  if (!confirm('確定要刪除這篇貼文嗎？刪除後無法恢復。')) return;
  
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  try {
    const dbRef = db.collection('users').doc(profileId);
    if (isWelcome) {
      await dbRef.set({ welcomePost: { isDeleted: true } }, { merge: true });
    } else if (isCustom) {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const customPosts = data.customPosts || [];
        const idx = customPosts.findIndex(s => s.id === id);
        if (idx !== -1) {
          customPosts[idx].isDeleted = true;
          await dbRef.update({ customPosts: customPosts });
        }
      }
    } else {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const summaries = data.dailySummaries || [];
        const idx = summaries.findIndex(s => s.date === id);
        if (idx !== -1) {
          summaries[idx].isDeleted = true;
          await dbRef.update({ dailySummaries: summaries });
        }
      }
    }
    toast('貼文已刪除！');
    window.location.reload();
  } catch (e) {
    console.error(e);
    toast('刪除失敗');
  }
};

window.toggleLikePost = async function(id, isWelcome, isCustom) {
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  const activeUserName = getActiveUserName();
  try {
    const dbRef = db.collection('users').doc(profileId);
    const toggleLike = (likedByList) => {
        const list = likedByList || [];
        const index = list.indexOf(activeUserName);
        if (index > -1) {
            list.splice(index, 1);
            return { list, liked: false };
        } else {
            list.push(activeUserName);
            return { list, liked: true };
        }
    };
    if (isWelcome) {
      const doc = await dbRef.get();
      const wPost = doc.data()?.welcomePost || {};
      const result = toggleLike(wPost.likedBy);
      await dbRef.set({ welcomePost: { likedBy: result.list, likes: result.list.length } }, { merge: true });
      toast(result.liked ? '已按讚動態！' : '已取消按讚！');
    } else if (isCustom) {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const customPosts = data.customPosts || [];
        const idx = customPosts.findIndex(s => s.id === id);
        if (idx !== -1) {
          const result = toggleLike(customPosts[idx].likedBy);
          customPosts[idx].likedBy = result.list;
          customPosts[idx].likes = result.list.length;
          await dbRef.update({ customPosts: customPosts });
          toast(result.liked ? '已按讚動態！' : '已取消按讚！');
        }
      }
    } else {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const summaries = data.dailySummaries || [];
        const idx = summaries.findIndex(s => s.date === id);
        if (idx !== -1) {
          const result = toggleLike(summaries[idx].likedBy);
          summaries[idx].likedBy = result.list;
          summaries[idx].likes = result.list.length;
          await dbRef.update({ dailySummaries: summaries });
          toast(result.liked ? '已按讚動態！' : '已取消按讚！');
        }
      }
    }
    window.location.reload();
  } catch (e) {
    console.error(e);
  }
};

window.addCommentToPost = function(id, isWelcome, isCustom) {
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  
  let modal = document.getElementById('commentPostModal');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'commentPostModal';
    modal.className = 'post-modal-overlay';
    modal.innerHTML = `<div class="post-modal-box"><div class="post-modal-title">新增留言</div><textarea id="commentPostTextarea" class="post-modal-textarea" placeholder="寫下你的留言..."></textarea><div class="post-modal-actions"><button class="post-modal-btn cancel" onclick="closeCommentModal()">取消</button><button class="post-modal-btn submit" id="commentPostSubmitBtn">發佈</button></div></div>`;
    document.body.appendChild(modal);
    
    window.closeCommentModal = function() {
      document.getElementById('commentPostModal').classList.remove('show');
    };
  }
  
  const textarea = document.getElementById('commentPostTextarea');
  textarea.value = '';
  
  const submitBtn = document.getElementById('commentPostSubmitBtn');
  submitBtn.onclick = async function() {
    const text = textarea.value.trim();
    if (!text) { toast('內容不能為空'); return; }
    
    submitBtn.textContent = '發佈中...';
    const author = getActiveUserName();
    const commentObj = {
      author: author,
      text: text,
      timestamp: new Date().toISOString()
    };
    
    try {
      const dbRef = db.collection('users').doc(profileId);
      if (isWelcome) {
        const doc = await dbRef.get();
        const wPost = doc.data()?.welcomePost || {};
        const comments = wPost.comments || [];
        comments.push(commentObj);
        await dbRef.set({ welcomePost: { comments: comments } }, { merge: true });
      } else if (isCustom) {
        const doc = await dbRef.get();
        if (doc.exists) {
          const data = doc.data();
          const customPosts = data.customPosts || [];
          const idx = customPosts.findIndex(s => s.id === id);
          if (idx !== -1) {
            const comments = customPosts[idx].comments || [];
            comments.push(commentObj);
            customPosts[idx].comments = comments;
            await dbRef.update({ customPosts: customPosts });
          }
        }
      } else {
        const doc = await dbRef.get();
        if (doc.exists) {
          const data = doc.data();
          const summaries = data.dailySummaries || [];
          const idx = summaries.findIndex(s => s.date === id);
          if (idx !== -1) {
            const comments = summaries[idx].comments || [];
            comments.push(commentObj);
            summaries[idx].comments = comments;
            await dbRef.update({ dailySummaries: summaries });
          }
        }
      }
      toast('留言已發佈！');
      window.closeCommentModal();
      window.location.reload();
    } catch (e) {
      console.error(e);
      toast('留言失敗');
    }
    submitBtn.textContent = '發佈';
  };
  
  modal.classList.add('show');
};

window.sharePost = function(id) {
  const dummyUrl = window.location.href.split('?')[0] + '?userId=' + getProfileUserId() + '&post=' + id;
  navigator.clipboard.writeText(dummyUrl).then(() => {
    toast('已複製動態連結！');
  }).catch(() => {
    toast('複製失敗');
  });
};

window.deleteComment = async function(postId, isWelcome, isCustom, commentIndex) {
  if (!confirm('確定要刪除這則留言嗎？')) return;
  
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  try {
    const dbRef = db.collection('users').doc(profileId);
    if (isWelcome) {
      const doc = await dbRef.get();
      const wPost = doc.data()?.welcomePost || {};
      const comments = wPost.comments || [];
      comments.splice(commentIndex, 1);
      await dbRef.set({ welcomePost: { comments: comments } }, { merge: true });
    } else if (isCustom) {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const customPosts = data.customPosts || [];
        const idx = customPosts.findIndex(s => s.id === postId);
        if (idx !== -1) {
          const comments = customPosts[idx].comments || [];
          comments.splice(commentIndex, 1);
          customPosts[idx].comments = comments;
          await dbRef.update({ customPosts: customPosts });
        }
      }
    } else {
      const doc = await dbRef.get();
      if (doc.exists) {
        const data = doc.data();
        const summaries = data.dailySummaries || [];
        const idx = summaries.findIndex(s => s.date === postId);
        if (idx !== -1) {
          const comments = summaries[idx].comments || [];
          comments.splice(commentIndex, 1);
          summaries[idx].comments = comments;
          await dbRef.update({ dailySummaries: summaries });
        }
      }
    }
    toast('留言已刪除！');
    window.location.reload();
  } catch (e) {
    console.error(e);
    toast('刪除失敗');
  }
};

window.openCreatePostModal = function() {
  const profileId = requireOwnProfileId();
  if (!profileId) return;
  
  let modal = document.getElementById('createPostModal');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'createPostModal';
    modal.className = 'post-modal-overlay';
    modal.innerHTML = `<div class="post-modal-box"><div class="post-modal-title">發佈新貼文</div><textarea id="createPostTextarea" class="post-modal-textarea" placeholder="分享你的自律故事與進度..."></textarea><div class="post-modal-actions"><button class="post-modal-btn cancel" onclick="closeCreatePostModal()">取消</button><button class="post-modal-btn submit" id="createPostSubmitBtn">發佈</button></div></div>`;
    document.body.appendChild(modal);
    
    window.closeCreatePostModal = function() {
      document.getElementById('createPostModal').classList.remove('show');
    };
  }
  
  const textarea = document.getElementById('createPostTextarea');
  textarea.value = '';
  
  const submitBtn = document.getElementById('createPostSubmitBtn');
  submitBtn.onclick = async function() {
    const text = textarea.value.trim();
    if (!text) { toast('內容不能為空'); return; }
    
    submitBtn.textContent = '發佈中...';
    try {
      const dbRef = db.collection('users').doc(profileId);
      const doc = await dbRef.get();
      const customPosts = doc.data()?.customPosts || [];
      
      const newPost = {
        id: 'custom_' + Date.now(),
        content: text,
        timestamp: Date.now(),
        likes: 0,
        likedBy: [],
        comments: [],
        isDeleted: false
      };
      
      customPosts.push(newPost);
      await dbRef.set({ customPosts: customPosts }, { merge: true });
      
      toast('貼文已發佈！');
      window.closeCreatePostModal();
      window.location.reload();
    } catch (e) {
      console.error(e);
      toast('發佈失敗');
    }
    submitBtn.textContent = '發佈';
  };
  
  modal.classList.add('show');
};
