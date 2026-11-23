import { HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";

const idPattern=/^[A-Za-z0-9_-]{8,128}$/;
export function normalizeGrowthDocument(data) {
  const fields={
    save:["action","documentId","revision","kind","title","body"],
    delete:["action","documentId","revision"],
    createTask:["action","taskId","title"],
  };
  const allowed=data&&fields[data.action];
  if(!allowed||Object.keys(data).length!==allowed.length||Object.keys(data).some(k=>!allowed.includes(k)))
    throw new HttpsError("invalid-argument","文件操作欄位不完整或含額外欄位。");
  const id=data.action==="createTask"?data.taskId:data.documentId;
  if(typeof id!=="string"||!idPattern.test(id))throw new HttpsError("invalid-argument","識別格式不正確。");
  if(data.action!=="createTask"&&(!Number.isInteger(data.revision)||data.revision<0||data.revision>1000000))
    throw new HttpsError("invalid-argument","文件版本不正確。");
  if(data.action!=="delete"&&(typeof data.title!=="string"||!data.title.trim()||data.title.trim().length>120))
    throw new HttpsError("invalid-argument","請提供120字內的標題。");
  if(data.action==="save"&&(!["letter","strategy"].includes(data.kind)||typeof data.body!=="string"||!data.body.trim()||data.body.trim().length>8000))
    throw new HttpsError("invalid-argument","請提供有效的文件種類與8000字內內容。");
  return {...data,...(data.title?{title:data.title.trim()}:{}),...(data.body?{body:data.body.trim()}:{})};
}
export function createManageGrowthDocumentHandler({firestore,clock=()=>new Date()}) {
  return async request=>{
    const uid=request.auth?.uid;
    if(typeof uid!=="string"||!uid||uid.includes("/")||request.auth?.token?.firebase?.sign_in_provider==="anonymous"||!request.app?.appId)
      throw new HttpsError("unauthenticated","請登入並完成 App Check。");
    const input=normalizeGrowthDocument(request.data),user=firestore.collection("users").doc(uid);
    return firestore.runTransaction(async tx=>{
      const [account,fence]=await Promise.all([tx.get(user),tx.get(firestore.collection("account_deletion_fences").doc(uid))]);
      if(!account.exists||fence.exists)throw new HttpsError("failed-precondition","帳號目前無法操作。");
      const now=clock();
      if(input.action==="createTask"){
        const tasks=account.data().tasks||[];
        if(!Array.isArray(tasks))throw new HttpsError("data-loss","任務資料需要整理。");
        const existing=tasks.find(t=>t.id===input.taskId);
        if(existing){
          if(existing.title!==input.title||existing.userId!==uid)throw new HttpsError("already-exists","任務版本不同。");
          return {taskId:input.taskId,status:"existing"};
        }
        if(tasks.length>=200)throw new HttpsError("resource-exhausted","請先整理既有任務。");
        const task={id:input.taskId,userId:uid,title:input.title,category:"自定義",taskType:"fixed",priority:"medium",
          isDone:false,isSystemTask:false,isAutoTracked:false,sourceType:"manual",createdAt:now.toISOString(),updatedAt:now.toISOString()};
        tx.update(user,{tasks:[...tasks,task]});
        return {taskId:task.id,status:"created"};
      }
      const ref=user.collection("growth_documents").doc(input.documentId);
      const tombstone=user.collection("growth_document_operations").doc(input.documentId);
      const [snapshot,operation]=await Promise.all([tx.get(ref),tx.get(tombstone)]);
      const existing=snapshot.exists?snapshot.data():null;
      if(input.action==="delete"){
        if(existing&&existing.revision!==input.revision)throw new HttpsError("aborted","另一裝置已更新；請重新讀取再刪除。");
        tx.delete(ref);
        tx.set(tombstone,{ownerUid:uid,status:"deleted",deletedAt:Timestamp.fromDate(now)});
        return {documentId:input.documentId,status:"deleted"};
      }
      if(operation.exists)throw new HttpsError("failed-precondition","此文件已刪除，請另寫一份新文件。");
      if(existing&&(existing.ownerUid!==uid||existing.kind!==input.kind))throw new HttpsError("permission-denied","文件種類或持有人不同。");
      if(existing&&existing.revision===input.revision+1&&["kind","title","body"].every(k=>existing[k]===input[k]))
        return {documentId:input.documentId,ownerUid:uid,revision:existing.revision,status:"saved",wasDuplicate:true};
      if((existing?.revision||0)!==input.revision)throw new HttpsError("aborted","另一裝置已修改；請重新讀取再編輯。");
      tx.set(ref,{schemaVersion:1,ownerUid:uid,kind:input.kind,title:input.title,body:input.body,revision:input.revision+1,
        createdAt:existing?.createdAt||Timestamp.fromDate(now),updatedAt:Timestamp.fromDate(now)});
      return {documentId:input.documentId,ownerUid:uid,revision:input.revision+1,status:"saved",wasDuplicate:false};
    });
  };
}
